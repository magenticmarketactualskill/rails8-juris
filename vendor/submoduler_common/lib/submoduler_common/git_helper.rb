require 'securerandom'
require 'time'

module SubmodulerCommon
  class GitHelper
    def self.run(command)
      `git #{command} 2>&1`
    end

    def self.success?
      $?.success?
    end

    # Enhanced functionality for change detection and management
    def self.detect_uncommitted_changes(submodule_path)
      changes = []
      
      # Get list of modified files
      Dir.chdir(submodule_path) do
        # Check for modified files
        modified_output = run("status --porcelain")
        return [] unless success?
        
        modified_output.split("\n").each do |line|
          next if line.strip.empty?
          
          status = line[0..1]
          file_path = line[3..-1]
          
          # Skip untracked files, focus on modifications (M in either position)
          next if status.strip == "??"
          next unless status.include?('M') || status.include?('A') || status.include?('D')
          
          # Create change record - we're already in the submodule directory
          change_record = create_change_record_in_submodule(file_path, submodule_path)
          changes << change_record if change_record
        end
      end
      
      changes
    end

    def self.create_change_record_in_submodule(file_path, original_submodule_path)
      # We're already in the submodule directory, so check file existence directly
      return nil unless File.exist?(file_path)
      
      # Get the diff for this file (we're already in the right directory)
      diff_output = run("diff HEAD -- #{file_path}")
      
      # Determine change type based on file extension and content
      change_type = categorize_change(file_path, diff_output)
      
      {
        file_path: file_path,
        full_path: File.join(original_submodule_path, file_path),
        submodule_path: original_submodule_path,
        change_type: change_type,
        diff: diff_output,
        timestamp: Time.now,
        auto_committed: false
      }
    end

    def self.create_change_record(file_path, submodule_path)
      full_path = File.join(submodule_path, file_path)
      return nil unless File.exist?(full_path)
      
      # Get the diff for this file
      diff_output = nil
      Dir.chdir(submodule_path) do
        diff_output = run("diff HEAD -- #{file_path}")
      end
      
      # Determine change type based on file extension and content
      change_type = categorize_change(file_path, diff_output)
      
      {
        file_path: file_path,
        full_path: full_path,
        submodule_path: submodule_path,
        change_type: change_type,
        diff: diff_output,
        timestamp: Time.now,
        auto_committed: false
      }
    end

    def self.categorize_change(file_path, diff_content)
      return :unknown if diff_content.nil? || diff_content.empty?
      
      case File.extname(file_path)
      when '.gemspec'
        if diff_content.include?('add_dependency') || diff_content.include?('add_development_dependency')
          :gemspec_dependency
        else
          :gemspec_metadata
        end
      when '.rb'
        if diff_content.include?('require')
          :require_statement
        else
          :ruby_code
        end
      else
        :other_file
      end
    end

    def self.generate_change_report(changes)
      return "No changes detected." if changes.empty?
      
      report = []
      report << "=== Submoduler Change Report ==="
      report << "Generated at: #{Time.now}"
      report << ""
      
      # Group changes by type
      changes_by_type = changes.group_by { |change| change[:change_type] }
      
      changes_by_type.each do |type, type_changes|
        report << "#{type.to_s.upcase.gsub('_', ' ')} Changes (#{type_changes.length}):"
        type_changes.each do |change|
          report << "  - #{change[:file_path]} (#{change[:submodule_path]})"
          if change[:auto_committed]
            report << "    Status: Auto-committed"
          else
            report << "    Status: Pending manual review"
          end
        end
        report << ""
      end
      
      report.join("\n")
    end

    def self.create_backup(submodule_paths = [])
      backup_id = SecureRandom.hex(8)
      backup_info = {
        backup_id: backup_id,
        timestamp: Time.now,
        submodule_states: {}
      }
      
      submodule_paths.each do |path|
        next unless Dir.exist?(path)
        
        Dir.chdir(path) do
          # Get current HEAD commit
          head_commit = run("rev-parse HEAD").strip
          next unless success?
          
          # Get current branch
          current_branch = run("rev-parse --abbrev-ref HEAD").strip
          current_branch = head_commit if current_branch == "HEAD" # detached HEAD
          
          backup_info[:submodule_states][path] = {
            head_commit: head_commit,
            branch: current_branch,
            has_uncommitted: !run("status --porcelain").strip.empty?
          }
        end
      end
      
      backup_info
    end

    def self.auto_commit_changes(changes, strategy = :selective)
      committed_changes = []
      
      changes.each do |change|
        should_commit = case strategy
        when :auto
          true
        when :selective
          is_standardization_change?(change)
        when :manual
          false
        when :dry_run
          false
        else
          false
        end
        
        if should_commit
          success = commit_single_change(change)
          if success
            change[:auto_committed] = true
            committed_changes << change
          end
        end
      end
      
      committed_changes
    end

    def self.is_standardization_change?(change)
      return false unless change[:diff]
      
      # Check for known standardization patterns
      diff = change[:diff]
      
      # Pattern 1: active_data_flow-core-core -> active_data_flow
      return true if diff.include?('active_data_flow-core-core') && diff.include?('active_data_flow')
      
      # Pattern 2: active_dataflow-* -> active_data_flow-* (can be on different lines)
      return true if diff.include?('active_dataflow-') && diff.include?('active_data_flow-')
      
      # Pattern 3: Require path standardization
      return true if change[:change_type] == :require_statement && 
                     diff.match?(/require.*active_data_flow/)
      
      false
    end

    def self.commit_single_change(change)
      Dir.chdir(change[:submodule_path]) do
        # Add the specific file
        run("add #{change[:file_path]}")
        return false unless success?
        
        # Create descriptive commit message
        message = generate_commit_message(change)
        
        # Commit the change
        run("commit -m \"#{message}\"")
        success?
      end
    end

    def self.generate_commit_message(change)
      case change[:change_type]
      when :gemspec_dependency
        "Standardize dependency names in #{File.basename(change[:file_path])}"
      when :require_statement
        "Standardize require paths in #{File.basename(change[:file_path])}"
      when :gemspec_metadata
        "Update gemspec metadata in #{File.basename(change[:file_path])}"
      else
        "Submoduler standardization: #{File.basename(change[:file_path])}"
      end
    end

    def self.validate_clean_status(submodule_paths = [])
      dirty_submodules = []
      
      submodule_paths.each do |path|
        next unless Dir.exist?(path)
        
        Dir.chdir(path) do
          status_output = run("status --porcelain")
          if success? && !status_output.strip.empty?
            dirty_submodules << {
              path: path,
              status: status_output.strip
            }
          end
        end
      end
      
      {
        clean: dirty_submodules.empty?,
        dirty_submodules: dirty_submodules
      }
    end

    def self.rollback_to_backup(backup_info, submodule_path)
      return false unless backup_info[:submodule_states][submodule_path]
      
      state = backup_info[:submodule_states][submodule_path]
      
      Dir.chdir(submodule_path) do
        # Reset to the backed up commit
        run("reset --hard #{state[:head_commit]}")
        return false unless success?
        
        # If we were on a specific branch, check it out
        if state[:branch] != state[:head_commit]
          run("checkout #{state[:branch]}")
          return false unless success?
        end
      end
      
      true
    end
  end
end
