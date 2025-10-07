# frozen_string_literal: true

# Verificar se o gem devise-two-factor está disponível
begin
  require 'devise-two-factor'
  DEVISE_TWO_FACTOR_AVAILABLE = true
rescue LoadError => e
  DEVISE_TWO_FACTOR_AVAILABLE = false
  puts "WARNING: Devise Two Factor gem not available: #{e.message}"
  
  # Definir um módulo dummy para evitar erros
  module Devise
    module Models
      module TwoFactorAuthenticatable
        # Módulo dummy para evitar NameError
        def self.included(base)
          # Não faz nada, apenas evita o erro
        end
      end
    end
  end
end
