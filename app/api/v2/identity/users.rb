# frozen_string_literal: true

require_dependency 'barong/jwt'

module API::V2
  module Identity
    class Users < Grape::API

      desc 'User related routes'
      resource :users do
        desc 'Creates new user',
        success: { code: 201, message: 'Creates new user' },
        failure: [
          { code: 400, message: 'Required params are missing' },
          { code: 422, message: 'Validation errors' }
        ]
        params do
          requires :email, type: String, desc: 'User Email', allow_blank: false
          requires :password, type: String, desc: 'User Password', allow_blank: false
          requires :recaptcha_response, type: String, desc: 'Response from Recaptcha widget'
        end
        post do
          user_params =  params.slice('email', 'password')
          user = User.new(user_params)
          verify_captcha!(user: user,
                          response: params['recaptcha_response'])

          error!(user.errors.full_messages, 422) unless user.save
        end

        desc 'Confirms an account',
        success: { code: 201, message: 'Confirms an account' },
        failure: [
          { code: 400, message: 'Required params are missing' },
          { code: 422, message: 'Validation errors' }
        ]
        params do
          requires :confirmation_token, type: String,
                                   desc: 'Token from email',
                                   allow_blank: false
        end
        post '/confirm' do
          payload = confirmation_codec.decode_and_verify(
            params[:confirmation_token], 
            pub_key: Barong::App.config.keystore.public_key
          )
          current_user = User.find_by_email(payload[:email])

          if current_user.nil? || current_user.active?
            error!('User doesn\'t exist or has already been activated', 422)
          end

          current_user.after_confirmation
          EventAPI.notify('system.user.email.confirmed', current_user.as_json_for_event_api)

          status 201
        end

        desc 'Send confirmations instructions',
        success: { code: 201, message: 'Generated verification code' },
        failure: [
          { code: 400, message: 'Required params are missing' },
          { code: 422, message: 'Validation errors' }
        ]
        params do
          requires :email, type: String,
                      desc: 'Account email',
                      allow_blank: false
        end
        post '/generate_confirmation' do
          current_user = User.find_by_email(params[:email])          
          if current_user.nil? || current_user.active?
            error!('User doesn\'t exist or has already been activated', 422)
          end

          token = confirmation_codec.encode({email: params[:email],uid: current_user.uid}.as_json)
          EventAPI.notify(
            'system.user.email.confirmation.token', 
            {user: current_user.as_json_for_event_api, token: token})
          status 201
        end

        # FIXME
        # desc 'Confirms an account',
        # success: { code: 201, message: 'Confirms an account' },
        # failure: [
        #   { code: 400, message: 'Required params are missing' },
        #   { code: 422, message: 'Validation errors' }
        # ]
        # params do
        #   requires :confirmation_token, type: String,
        #                                 desc: 'Confirmation jwt token',
        #                                 allow_blank: false
        # end
        # post '/confirm' do
        #   WIP : confirmation logic
        # end

        # desc 'Unlocks an account',
        # success: { code: 201, message: 'Unlocks an account' },
        # failure: [
        #   { code: 400, message: 'Required params are missing' },
        #   { code: 422, message: 'Validation errors' }
        # ]
        # params do
        #   requires :unlock_token, type: String,
        #                           desc: 'Unlock jwt token',
        #                           allow_blank: false
        # end
        # post '/unlock' do
        #   WIP : unlock logic
        # end

        # desc 'Sets new account password',
        #      failure: [
        #        { code: 400, message: 'Required params are empty' },
        #        { code: 404, message: 'Record is not found' },
        #        { code: 422, message: 'Validation errors' }
        #      ]
        # params do
        #   requires :reset_password_token, type: String,
        #                                   desc: 'Token from email',
        #                                   allow_blank: false
        #   requires :password, type: String,
        #                       desc: 'User password',
        #                       allow_blank: false
        # end
        # put '/reset_password' do
        #   required_params = declared(params)
        #                     .merge(password_confirmation: params[:password])

        #   user = User.reset_password_by_token(required_params)
        #   raise ActiveRecord::RecordNotFound unless user.persisted?

        #   if user.errors.any?
        #     error!(user.errors.full_messages.to_sentence, 422)
        #   end
        # end
      end
    end
  end
end
