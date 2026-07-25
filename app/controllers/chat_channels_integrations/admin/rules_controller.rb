# frozen_string_literal: true

module ChatChannelsIntegrations
  module Admin
    class RulesController < ::Admin::AdminController
      requires_plugin ChatChannelsIntegrations::PLUGIN_NAME

      def index
        rules = Rule.includes(:chat_channel).order(:chat_channel_id, :id)
        channels =
          ::Chat::Channel.public_channels.order(:name, :id).map do |channel|
            { id: channel.id, name: channel.title(current_user) }
          end

        render json: {
                 rules: serialize_data(rules, RuleSerializer),
                 channels: channels,
               }
      end

      def create
        rule = Rule.new(rule_params)

        if rule.save
          render json: { rule: serialize_data(rule, RuleSerializer) }, status: :created
        else
          render_json_error(rule)
        end
      end

      def update
        rule = Rule.find(params[:id])

        if rule.update(rule_params)
          render json: { rule: serialize_data(rule, RuleSerializer) }
        else
          render_json_error(rule)
        end
      end

      def destroy
        Rule.find(params[:id]).destroy!
        render json: success_json
      end

      private

      def rule_params
        params.require(:rule).permit(:chat_channel_id, :matrix_room_id, :enabled)
      end
    end
  end
end
