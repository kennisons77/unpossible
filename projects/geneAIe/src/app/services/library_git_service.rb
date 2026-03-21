require 'open3'

class LibraryGitService
  class GitError < StandardError; end

  def initialize(library_path: nil)
    @library_path = library_path || ENV.fetch('LIBRARY_PATH', Rails.root.join('library').to_s)
  end

  def write_and_commit(document:, content:, source: 'llm')
    relative_path = file_path_for(document)
    absolute_path = File.join(@library_path, relative_path)

    ensure_repo_initialized
    write_file(absolute_path, content)
    stage_and_commit(relative_path, commit_message(document, source))

    relative_path
  end

  private

  def file_path_for(document)
    concern_name = sanitize_path_segment(document.concern&.name || 'uncategorized')
    doc_type = sanitize_path_segment(document.document_type || 'unknown')

    File.join(concern_name, doc_type, "#{document.id}.md")
  end

  def sanitize_path_segment(segment)
    segment.downcase.gsub(/[^a-z0-9_-]/, '_').gsub(/_+/, '_').chomp('_')
  end

  def ensure_repo_initialized
    FileUtils.mkdir_p(@library_path)
    return if File.directory?(File.join(@library_path, '.git'))

    git('init')
    git('config', 'user.email', 'sovereign-library@local')
    git('config', 'user.name', 'Sovereign Library')
  end

  def write_file(absolute_path, content)
    FileUtils.mkdir_p(File.dirname(absolute_path))
    File.write(absolute_path, content)
  end

  def stage_and_commit(relative_path, message)
    git('add', relative_path)
    git('commit', '-m', message)
  end

  def commit_message(document, source)
    "doc:#{document.id} stage:#{document.stage} source:#{source} at:#{Time.current.iso8601}"
  end

  def git(*args)
    stdout, stderr, status = Open3.capture3('git', *args, chdir: @library_path)
    raise GitError, "git #{args.first} failed: #{stderr.strip}" unless status.success?

    stdout
  end
end
