# frozen_string_literal: true
# Copyright 2022 Hummingbird RegTech, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
module RSpec
  module InlineSnapshot
    module Matchers
      extend RSpec::Matchers::DSL

      RSpec.configure do |config|
        config.after(:suite) do
          REWRITERS.each do |source_file_path, (_parsed_source, corrector)|
            File.write(source_file_path, corrector.process)
          end

          REWRITERS.clear
        end
      end

      UNDEFINED_EXPECTED_VALUE = :_inline_snapshot_undefined
      # FIXME: there's probably a way to do this without abusing a constant but it works for now
      # file => [parsed_source, corrector]
      REWRITERS = {}

      FALSE_VALUES = [
        nil,
        '',
        '0',
        'f',
        'false',
        'off'
      ].to_set.freeze

      # This is fiddly. The AST is a bit annoying in that the #location and/or #source_range of
      # a SendNode are only the expression, and do not consistently include recursive children in the range.
      # So we have to do the math ourselves... case by case. We aim for the range to start
      # at the open parentheses (if there is one) and end at the close parentheses or heredoc terminator.
      def replacement_range(node, parsed_source)
        matcher_arg = node.arguments.last

        if matcher_arg.nil? && node.location.begin.nil?
          # no-args command-style call. ie. "match_inline_snapshot"
          Parser::Source::Range.new(
            parsed_source.buffer,
            node.location.expression.end_pos,
            node.location.expression.end_pos
          )
        elsif matcher_arg.is_a?(RuboCop::AST::StrNode) && matcher_arg.heredoc?
          # with heredoc parameter ie. "match_inline_snapshot(<<~SNAP) ... SNAP"
          Parser::Source::Range.new(
            parsed_source.buffer,
            node.location.begin.begin_pos,
            node.arguments.last.location.heredoc_end.end_pos
          )
        elsif matcher_arg.is_a?(RuboCop::AST::SendNode) &&
              matcher_arg.receiver.heredoc? &&
              matcher_arg.method_name == :chomp
          # with chomped heredoc parameter ie. "match_inline_snapshot(<<~SNAP.chomp) ... SNAP"
          Parser::Source::Range.new(
            parsed_source.buffer,
            node.location.begin.begin_pos,
            matcher_arg.receiver.location.heredoc_end.end_pos
          )
        else
          # no-args call with parens. ie. "match_inline_snapshot()"
          # or with a plain old parameter ie. "match_inline_snapshot('foo')"
          Parser::Source::Range.new(
            parsed_source.buffer,
            node.location.begin.begin_pos,
            node.location.end.end_pos
          )
        end
      end

      # Format the actual value so it can be injected into the source as the new argument.
      def format_replacement(actual, node, parsed_source)
        if actual.is_a?(String)
          if actual.include?("\n")
            indent = parsed_source.line_indentation(node.location.first_line)
            [
              '(<<~SNAP.chomp)',
              actual.split("\n", -1).map { |line| "#{' ' * (indent + 2)}#{line}" },
              "#{' ' * indent}SNAP"
            ].join("\n")
          else
            "(#{actual.inspect})"
          end
        elsif actual.is_a?(NilClass) || actual.is_a?(Integer) || actual.is_a?(TrueClass) || actual.is_a?(FalseClass)
          "(#{actual.inspect})"
        elsif actual.respond_to?(:as_json)
          "(#{actual.as_json.inspect})"
        else
          raise ArgumentError,
                "Cannot snapshot. Actual (#{actual.class}) is not a String and does not implement #as_json"
        end
      end

      def should_update_inline_snapshot?(expected)
        env_to_boolean(ENV['UPDATE_MATCH_SNAPSHOT']) ||
          env_to_boolean(ENV['UPDATE_SNAPSHOTS']) ||
          expected == UNDEFINED_EXPECTED_VALUE
      end

      def running_in_ci?
        env_to_boolean(ENV['CI'])
      end

      def match_or_update_inline_snapshot(matcher_name, expected, actual)
        if should_update_inline_snapshot?(expected)
          return false if running_in_ci?

          # General algorithm:
          #   1. Get location. RSpec.current_example.location
          #   2. Crawl Kernel.caller_locations until first hit at #absolute_path from 1
          #   3. Use #lineno as heuristic to find call to :match_inline_snapshot (matcher_name) in AST
          #   4. Rewrite first argument of method call
          source_file_path = RSpec.current_example.metadata[:absolute_file_path]
          caller_location = Kernel.caller_locations.detect do |cl|
            cl.absolute_path == RSpec.current_example.metadata[:absolute_file_path]
          end
          matcher_call_line_number = caller_location.lineno

          # Parse the spec file.
          # See:
          #   https://www.rubydoc.info/github/whitequark/parser/Parser/TreeRewriter
          #   https://medium.com/flippengineering/using-rubocop-ast-to-transform-ruby-files-using-abstract-syntax-trees-3e352e9ac916
          REWRITERS[source_file_path] ||= begin
            parsed_source = RuboCop::AST::ProcessedSource.from_file(source_file_path,
                                                                    RUBY_VERSION.match(/\d+\.\d+/).to_s.to_f)
            corrector = ::RuboCop::Cop::Corrector.new(parsed_source)
            [parsed_source, corrector]
          end

          parsed_source, corrector = REWRITERS[source_file_path]

          parsed_source.ast.each_node(:send) do |node|
            next unless node.location.first_line >= matcher_call_line_number && node.method_name == matcher_name

            # found it! well we hope anyway because we're about to blow something away!
            corrector.replace(replacement_range(node, parsed_source), format_replacement(actual, node, parsed_source))

            return true # we replaced the target argument and overwrote the file. no point going further in this spec file.
          end
          raise "possible bug in inline snapshot matcher. Did not locate call to #{matcher_name} in #{source_file_path}"
        else
          RSpec::Support::FuzzyMatcher.values_match?(expected, actual)
        end
      end

      def env_to_boolean(value)
        !FALSE_VALUES.include?(value&.downcase)
      end

      matcher :match_inline_snapshot do |expected = UNDEFINED_EXPECTED_VALUE|
        diffable

        match do |actual|
          match_or_update_inline_snapshot(:match_inline_snapshot, expected, actual)
        end

        failure_message do |_actual|
          if running_in_ci? && should_update_inline_snapshot?(expected)
            'cannot update snapshots in CI. Did you forget to check it in?'
          else
            # NB: yes this works.
            # The failure_message macro gets turned into a method definition by rspec
            super()
          end
        end
      end
    end
  end
end
