# TODO: Wrap the schema lib under ai-agents
# So we can extend it as Agents::Schema

# Verificar se RubyLLM está disponível
begin
  require 'ruby_llm'
  RUBY_LLM_AVAILABLE = true
rescue LoadError => e
  RUBY_LLM_AVAILABLE = false
  puts "WARNING: RubyLLM gem not available: #{e.message}"
end

if RUBY_LLM_AVAILABLE
  class Captain::ResponseSchema < RubyLLM::Schema
    string :response, description: 'The message to send to the user'
    string :reasoning, description: "Agent's thought process"
  end
else
  # Definir uma classe dummy para evitar NameError
  class Captain::ResponseSchema
    def self.string(name, **options)
      # Método dummy para evitar erros
    end
  end
end
