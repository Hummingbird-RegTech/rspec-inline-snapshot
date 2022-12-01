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
require 'json'
require 'rspec-inline-snapshot'

RSpec.describe RSpec::InlineSnapshot::Matchers do
  let(:snapshot_content) { '' }

  describe ':match_inline_snapshot' do
    before do
      stub_const('RSpec::InlineSnapshot::Matchers::REWRITERS', {})
      allow(::RuboCop::Cop::Corrector).to receive(:new).once do |source_buffer|
        @source_buffer = source_buffer
        mock_corrector
      end

      # Ensure we don't blow away this very spec file by stubbing the corrector to always
      # return the original file content.
      allow(mock_corrector).to receive(:process).and_return(File.read(__FILE__))
      allow(mock_corrector).to(receive(:source_buffer)) { @source_buffer }
    end

    around do |ex|
      old_env = ENV.slice('UPDATE_MATCH_SNAPSHOT', 'UPDATE_SNAPSHOTS', 'CI')

      ENV['UPDATE_SNAPSHOTS'] = update_snapshots.to_s
      ENV['UPDATE_MATCH_SNAPSHOT'] = update_match_snapshot.to_s
      ENV['CI'] = ci

      ex.call
    ensure
      ENV.merge!(old_env)
    end

    let(:update_snapshots) { nil }
    let(:ci) { nil }
    let(:mock_corrector) { instance_double(::RuboCop::Cop::Corrector) }

    context 'UPDATE_MATCH_SNAPSHOT=true' do
      let(:update_match_snapshot) { true }

      context 'no value is provided yet' do
        it 'updates the inline snapshot' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: ''),
            '("actual_value_bananas")'
          )
          expect('actual_value_bananas').to match_inline_snapshot
        end
      end

      context 'existing expected value was a string' do
        it 'updates the inline snapshot' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: "('apples')"),
            '("oranges")'
          )
          expect('oranges').to match_inline_snapshot('apples')
        end
      end

      context 'existing value is not on the same line as the expect call' do
        it 'updates the inline snapshot' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: "('apples')"),
            '("oranges")'
          )
          expect('oranges').to eq('oranges').and(
            have_attributes(length: 7).and(
              match_inline_snapshot('apples')
            )
          )
        end
      end

      context 'existing expected value was an unchomped heredoc' do
        it 'updates the inline snapshot' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: /\(<<~SNAP\)\n\s+Shopping list:\n\s+\* apples\n\s+SNAP/),
            /\(<<~SNAP.chomp\)\n\s+Hit list:\n\s+\* cool tests\n\s+SNAP/
          )
          expect("Hit list:\n  * cool tests").to match_inline_snapshot(<<~SNAP)
            Shopping list:
              * apples
          SNAP
        end
      end

      context 'existing expected value was a heredoc' do
        it 'updates the inline snapshot' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: /\(<<~SNAP.chomp\)\n\s+Shopping list:\n\s+\* apples\n\s+SNAP/),
            /\(<<~SNAP.chomp\)\n\s+Hit list:\n\s+\* cool tests\n\s+SNAP/
          )
          expect("Hit list:\n  * cool tests").to match_inline_snapshot(<<~SNAP.chomp)
            Shopping list:
              * apples
          SNAP
        end
      end

      context 'new value is nil' do
        it 'updates the inline snapshot' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: ''),
            '(nil)'
          )
          expect(nil).to match_inline_snapshot
        end
      end

      context 'new value is an integer' do
        it 'updates the inline snapshot' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: ''),
            '(123)'
          )
          expect(123).to match_inline_snapshot
        end
      end

      context 'new value is a string without newlines' do
        it 'updates the inline snapshot with a normal string' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: ''),
            '("foo")'
          )
          expect('foo').to match_inline_snapshot
        end
      end

      context 'new value is a string with newlines' do
        it 'updates the inline snapshot with a heredoc' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: ''),
            /\(<<~SNAP.chomp\)\n\s{12}foo\n\s{12}bar\n\s{10}SNAP/
          )
          expect("foo\nbar").to match_inline_snapshot
        end
      end

      context 'new value ends in a newline' do
        it 'updates the inline snapshot with a heredoc preserving the newline' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: ''),
            /\(<<~SNAP.chomp\)\n\s{12}foo\n\s{12}bar\n\s{12}\n\s{10}SNAP/
          )
          expect("foo\nbar\n").to match_inline_snapshot
        end
      end
    end

    context 'UPDATE_MATCH_SNAPSHOT=false' do
      let(:update_match_snapshot) { false }

      context 'no value is provided yet' do
        it 'updates the inline snapshot' do
          expect(mock_corrector).to receive(:replace).with(
            have_attributes(source: ''),
            '("actual_value_bananas")'
          )
          expect('actual_value_bananas').to match_inline_snapshot
        end

        context 'running in CI such as CircleCI' do
          let(:ci) { 'true' }

          it 'does not update the snapshot and fails test' do
            expect(mock_corrector).not_to receive(:replace)
            expect do
              expect('actual_value_bananas').to match_inline_snapshot
            end.to raise_error(
                     RSpec::Expectations::ExpectationNotMetError,
                     'cannot update snapshots in CI. Did you forget to check it in?'
                   )
          end
        end
      end

      context 'actual value does not match snapshot' do
        it 'does not update the snapshot and fails test' do
          expect(mock_corrector).not_to receive(:replace)
          expect do
            expect('actual_value_bananas').to match_inline_snapshot(nil)
          end.to raise_error(
                   RSpec::Expectations::ExpectationNotMetError,
                   'expected "actual_value_bananas" to match inline snapshot nil'
                 )
        end
      end

      context 'the actual value matches expected value' do
        it 'passes' do
          expect(mock_corrector).not_to receive(:replace)

          expect do
            expect('passing test green yay').to match_inline_snapshot('passing test green yay')
          end.not_to raise_error

          expect do
            expect(123).to match_inline_snapshot(123)
          end.not_to raise_error

          expect do
            expect(nil).to match_inline_snapshot(nil)
          end.not_to raise_error

          expect do
            expect({ a: 1 }).to match_inline_snapshot({ a: 1 })
          end.not_to raise_error

          expect do
            expect(JSON.pretty_generate({ a: 1, b: 2, c: { d: 3, e: 4 } })).to match_inline_snapshot(<<~SNAP.chomp)
              {
                "a": 1,
                "b": 2,
                "c": {
                  "d": 3,
                  "e": 4
                }
              }
            SNAP
          end.not_to raise_error
        end
      end

      context 'the actual value does not match expected value' do
        it 'fails' do
          expect(mock_corrector).not_to receive(:replace)
          expect do
            expect('passing test green yay').to match_inline_snapshot('failing test red bad')
          end.to raise_error(
                   RSpec::Expectations::ExpectationNotMetError,
                   'expected "passing test green yay" to match inline snapshot "failing test red bad"'
                 )
        end
      end
    end
  end
end
# rubocop:enable RSpec/ExpectActual
