require 'omniauth-oauth2'

# OmniAuth strategy for connecting to the ORCID contributor ID service via the OAuth 2.0 protocol

module OmniAuth
  module Strategies
    class ORCID < OmniAuth::Strategies::OAuth2

      DEFAULT_SCOPE = '/authenticate'
      API_VERSION = '1.2'

      option :name, "orcid"

      option :member, false
      option :sandbox, false
      option :provider_ignores_state, true

      option :authorize_options, [:redirect_uri, :show_login]

      args [:client_id, :client_secret]

      def initialize(app, *args, &block)
        super

        @options.client_options.site          = site
        @options.client_options.authorize_url = authorize_url
        @options.client_options.token_url     = token_url
        @options.client_options.scope         = scope
      end

      def authorize_params
        super.tap do |params|
          %w[scope redirect_uri show_login lang].each do |v|
            if request.params[v]
              params[v.to_sym] = request.params[v]
            end
          end

          params[:scope] ||= DEFAULT_SCOPE
          params[:show_login] ||= 'true'
        end
      end

      # URLs for ORCID OAuth: http://members.orcid.org/api/tokens-through-3-legged-oauth-authorization
      def namespace
        if options[:member] && options[:sandbox]
          'sandbox'
        elsif options[:member]
          'production'
        elsif options[:sandbox]
          'public_sandbox'
        else
          'public'
        end
      end

      def site
        case namespace
        when 'sandbox' then 'http://api.sandbox.orcid.org'
        when 'production' then 'http://api.orcid.org'
        when 'public_sandbox' then 'http://pub.sandbox.orcid.org'
        when 'public' then 'http://pub.orcid.org'
        end
      end

      def authorize_url
        if options[:sandbox]
          'https://sandbox.orcid.org/oauth/authorize'
        else
          'https://orcid.org/oauth/authorize'
        end
      end

      def token_url
        case namespace
        when 'sandbox' then 'https://api.sandbox.orcid.org/oauth/token'
        when 'production' then 'https://api.orcid.org/oauth/token'
        when 'public_sandbox' then 'https://pub.sandbox.orcid.org/oauth/token'
        when 'public' then 'https://pub.orcid.org/oauth/token'
        end
      end

      def scope
        if options[:member]
          '/orcid-profile/read-limited /orcid-works/create'
        else
          '/authenticate'
        end
      end

      uid { access_token.params["orcid"] }

      info do
        { name: access_token.params["name"] }
      end

      extra do
        hsh = {}
        hsh[:raw_info] = raw_info unless skip_info?
        prune! hash
      end

      def raw_info
        @raw_info ||= access_token.get("#{site}/v#{API_VERSION}/#{uid}/orcid-bio").parsed
      end
    end
  end
end

OmniAuth.config.add_camelization 'orcid', 'ORCID'
