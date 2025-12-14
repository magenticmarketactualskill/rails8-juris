module SubmodulerCommon
  class Command
    def initialize
      @logger = SubmodulerCommon::Logger.new
    end

    def logger
      @logger
    end

    def handle_error(e)
      logger.error "Error: #{e.message}"
      e.backtrace.first(5).each { |line| logger.error line }
    end
  end
end
