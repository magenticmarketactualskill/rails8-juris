# frozen_string_literal: true

module SubmodulerCommon
  class ChangeDetector
    def initialize(submodule_path)
      @submodule_path = submodule_path
    end

    def detect_uncommitted_changes
      changes = []
      
      # Check for uncommitted working tree changes
      working_tree_changes = detect_working_tree_changes
      changes.concat(working_tree_changes) if working_tree_changes.any?
      
      # Check for unpushed commits
      unpushed_commits = detect_unpushed_commits
      changes.concat(unpushed_commits) if unpushed_commits.any?
      
      changes
    end

    def has_changes?
      !detect_uncommitted_changes.empty?
    end

    def git_clean?
      output = `git -C "#{@submodule_path}" status --porcelain`
      output.strip.empty?
    end

    def has_unpushed_commits?
      # Check if local branch is ahead of remote
      output = `git -C "#{@submodule_path}" status --porcelain=v1 --branch`
      output.include?('[ahead')
    end

    private

    def detect_working_tree_changes
      output = `git -C "#{@submodule_path}" status --porcelain`
      return [] if output.strip.empty?

      changes = []
      output.each_line do |line|
        status = line[0..1]
        file_path = line[3..-1].strip
        
        change_type = categorize_change(file_path, status)
        changes << {
          type: :working_tree,
          change_type: change_type,
          file_path: file_path,
          status: status,
          submodule: @submodule_path
        }
      end
      
      changes
    end

    def detect_unpushed_commits
      # Get commits that are ahead of remote
      output = `git -C "#{@submodule_path}" log --oneline @{u}..HEAD 2>/dev/null`
      return [] if $?.exitstatus != 0 || output.strip.empty?

      changes = []
      output.each_line do |line|
        commit_hash = line.split(' ').first
        commit_message = line.split(' ', 2).last.strip
        
        changes << {
          type: :unpushed_commit,
          change_type: :commit,
          commit_hash: commit_hash,
          commit_message: commit_message,
          submodule: @submodule_path
        }
      end
      
      changes
    end

    def categorize_change(file_path, status)
      case file_path
      when /\.gemspec$/
        :gemspec_dependency
      when /lib\/.*\/version\.rb$/
        :version_update
      when /lib\/.*\.rb$/
        if File.read(File.join(@submodule_path, file_path)).include?('require')
          :require_statement
        else
          :code_change
        end
      when /README\.md$/
        :documentation
      else
        :other
      end
    rescue StandardError
      :other
    end
  end
end