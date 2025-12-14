module SubmodulerCommon
  class Logger
    def initialize(output = $stdout)
      @output = output
    end

    def info(message)
      @output.puts "\e[32mINFO: #{message}\e[0m"
    end

    def error(message)
      @output.puts "\e[31mERROR: #{message}\e[0m"
    end
  end
end
