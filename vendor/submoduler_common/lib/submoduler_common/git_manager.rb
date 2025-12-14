# frozen_string_literal: true

module SubmodulerCommon
  class GitManager
    def initialize(submodule_path)
      @submodule_path = submodule_path
    end

    def auto_commit_changes(message)
      return false unless has_working_tree_changes?

      puts "  Staging changes in #{@submodule_path}..."
      result = system("git -C \"#{@submodule_path}\" add .")
      return false unless result

      puts "  Committing changes in #{@submodule_path}..."
      result = system("git -C \"#{@submodule_path}\" commit -m '#{message}'")
      return false unless result

      true
    end

    def push_to_remote
      puts "  Pushing changes in #{@submodule_path}..."
      
      # Push commits
      result = system("git -C \"#{@submodule_path}\" push")
      return false unless result

      # Push tags if any
      system("git -C \"#{@submodule_path}\" push --tags")
      
      true
    end

    def validate_clean_status
      detector = ChangeDetector.new(@submodule_path)
      detector.git_clean? && !detector.has_unpushed_commits?
    end

    def create_backup
      # Create a backup branch with timestamp
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      backup_branch = "submoduler_backup_#{timestamp}"
      
      puts "  Creating backup branch: #{backup_branch}"
      system("git -C \"#{@submodule_path}\" branch #{backup_branch}")
      
      backup_branch
    end

    def get_current_branch
      output = `git -C "#{@submodule_path}" branch --show-current`
      output.strip
    end

    def get_remote_status
      # Fetch to get latest remote info
      system("git -C \"#{@submodule_path}\" fetch --quiet")
      
      # Check status relative to remote
      output = `git -C "#{@submodule_path}" status --porcelain=v1 --branch`
      
      if output.include?('[ahead')
        :ahead
      elsif output.include?('[behind')
        :behind
      elsif output.include?('[ahead') && output.include?('behind')
        :diverged
      else
        :up_to_date
      end
    end

    private

    def has_working_tree_changes?
      output = `git -C "#{@submodule_path}" status --porcelain`
      !output.strip.empty?
    end
  end
end