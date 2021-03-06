module Agents
  class GapDetectorAgent < Agent
    default_schedule 'every_10m'

    description <<-MD
      Watches for holes or gaps in a stream of incoming messages and generates "no data alerts".

      The `value_path` value is a [JSONPath](http://goessner.net/articles/JsonPath/) to a value of interest. If either
      this value is empty, or no messages are received, during `window_duration_in_days`, a message will be created with
      a payload of `message`.
    MD

    message_description <<-MD
      Messages look like:

          {
            "message": "No data has been received!",
            "gap_started_at": "1234567890"
          }
    MD

    def validate_options
      unless options['message'].present?
        errors.add(:base, 'message is required')
      end

      unless options['window_duration_in_days'].present? && options['window_duration_in_days'].to_f > 0
        errors.add(:base, 'window_duration_in_days must be provided as an integer or floating point number')
      end
    end

    def default_options
      {
        'window_duration_in_days' => '2',
        'message' => 'No data has been received!'
      }
    end

    def receive(message)
      memory['newest_message_created_at'] ||= 0

      if !interpolated['value_path'].present? || Utils.value_at(message.payload, interpolated['value_path']).present?
        if message.created_at.to_i > memory['newest_message_created_at']
          memory['newest_message_created_at'] = message.created_at.to_i
          memory.delete('alerted_at')
        end
      end
    end

    def check
      window = interpolated['window_duration_in_days'].to_f.days.ago
      if memory['newest_message_created_at'].present? && Time.at(memory['newest_message_created_at']) < window
        unless memory['alerted_at']
          memory['alerted_at'] = Time.now.to_i
          create_message payload: { message: interpolated['message'],
                                    gap_started_at: memory['newest_message_created_at'] }
        end
      end
    end
  end
end
