# frozen_string_literal: true

require_relative 'submoduler_common/version'
require_relative 'submoduler_common/submoduler_ini'
require_relative 'submoduler_common/change_detector'
require_relative 'submoduler_common/git_manager'
require_relative 'submoduler_common/git_helper'
require_relative 'submoduler_common/logger'
require_relative 'submoduler_common/command'

module SubmodulerCommon
  class Error < StandardError; end
end