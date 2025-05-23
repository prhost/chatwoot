class Captain::Copilot::ResponseJob < ApplicationJob
  queue_as :default

  def perform(assistant:, conversation_id:, user_id:, copilot_thread_id:, message:)
    Rails.logger.info("[Captain::Copilot::BuildResponseJob] Starting job for user_id=#{user.id}")
    generate_chat_response(assistant, conversation_id, user_id, copilot_thread_id, message)
  end

  private

  def generate_chat_response(assistant, conversation_id, user_id, copilot_thread_id, message)
    Captain::Copilot::ChatService.new(
      assistant,
      user_id: user_id,
      copilot_thread_id: copilot_thread_id,
      conversation_id: conversation_id
    ).generate_response(message)
  end
end
