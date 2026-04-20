# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

RSpec.describe LedgerAppender do
  let(:ledger_path) { File.join(Dir.mktmpdir, 'LEDGER.jsonl') }

  let(:status_event) do
    { ts: '2026-04-17T14:00:00Z', type: 'status', ref: '1.1', from: 'todo', to: 'in_progress', sha: nil, reason: 'picked up' }
  end

  describe '.append' do
    it 'appends a valid JSON line to the file' do
      described_class.append(status_event, path: ledger_path)
      lines = File.readlines(ledger_path, chomp: true)
      expect(lines.length).to eq(1)
      expect(JSON.parse(lines.first)['type']).to eq('status')
    end

    it 'creates the file if it does not exist' do
      expect(File.exist?(ledger_path)).to be false
      described_class.append(status_event, path: ledger_path)
      expect(File.exist?(ledger_path)).to be true
    end

    it 'appends multiple events as separate lines' do
      blocked_event = { ts: '2026-04-17T14:01:00Z', type: 'blocked', ref: '2.1', by: '1.1', reason: 'needs ledger' }
      described_class.append(status_event, path: ledger_path)
      described_class.append(blocked_event, path: ledger_path)
      expect(File.readlines(ledger_path, chomp: true).length).to eq(2)
    end

    it 'is idempotent — duplicate entries are not appended' do
      described_class.append(status_event, path: ledger_path)
      described_class.append(status_event, path: ledger_path)
      expect(File.readlines(ledger_path, chomp: true).length).to eq(1)
    end

    context 'with each valid event type' do
      %w[status blocked unblocked spec_changed pr_opened pr_review pr_merged].each do |type|
        it "accepts type '#{type}'" do
          event = { ts: '2026-04-17T14:00:00Z', type: type }
          expect { described_class.append(event, path: ledger_path) }.not_to raise_error
        end
      end
    end

    context 'with an invalid event type' do
      it 'raises InvalidEventType' do
        bad_event = { ts: '2026-04-17T14:00:00Z', type: 'deleted' }
        expect { described_class.append(bad_event, path: ledger_path) }
          .to raise_error(LedgerAppender::InvalidEventType)
      end
    end

    it 'does not modify existing entries (file is append-only)' do
      described_class.append(status_event, path: ledger_path)
      original_first_line = File.readlines(ledger_path, chomp: true).first

      second_event = { ts: '2026-04-17T14:02:00Z', type: 'unblocked', ref: '2.1', by: '1.1', reason: 'done' }
      described_class.append(second_event, path: ledger_path)

      expect(File.readlines(ledger_path, chomp: true).first).to eq(original_first_line)
    end
  end
end
