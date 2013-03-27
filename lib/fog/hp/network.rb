require 'fog/hp'

module Fog
  module HP
    class Network < Fog::Service

      requires    :hp_access_key, :hp_secret_key, :hp_tenant_id, :hp_avl_zone
      recognizes  :hp_auth_uri
      recognizes  :persistent, :connection_options
      recognizes  :hp_use_upass_auth_style, :hp_auth_version, :user_agent

      secrets     :hp_secret_key

      request_path 'fog/hp/requests/network'
      request :add_router_interface
      request :associate_floating_ip
      request :create_floating_ip
      request :create_network
      request :create_port
      request :create_router
      request :create_subnet
      request :disassociate_floating_ip
      request :delete_floating_ip
      request :delete_network
      request :delete_port
      request :delete_router
      request :delete_subnet
      request :get_floating_ip
      request :get_network
      request :get_port
      request :get_router
      request :get_subnet
      request :list_floating_ips
      request :list_networks
      request :list_ports
      request :list_routers
      request :list_subnets
      request :remove_router_interface
      request :update_network
      request :update_port
      request :update_router
      request :update_subnet

      module Utils

      end

      class Mock
        include Utils

        def self.data
          @data ||= Hash.new do |hash, key|
            hash[key] = {
              :floating_ips => {},
              :networks => {},
              :ports => {},
              :routers => {},
              :subnets => {}
            }
          end
        end

        def self.reset
          @data = nil
        end

        def initialize(options={})
          @hp_access_key = options[:hp_access_key]
        end

        def data
          self.class.data[@hp_access_key]
        end

        def reset_data
          self.class.data.delete(@hp_access_key)
        end

      end

      class Real
        include Utils

        def initialize(options={})
          @hp_access_key = options[:hp_access_key]
          @hp_secret_key = options[:hp_secret_key]
          @hp_auth_uri   = options[:hp_auth_uri]
          @connection_options = options[:connection_options] || {}
          ### Set an option to use the style of authentication desired; :v1 or :v2 (default)
          auth_version = options[:hp_auth_version] || :v2
          ### Pass the service name for object storage to the authentication call
          options[:hp_service_type] = "Networking"
          @hp_tenant_id = options[:hp_tenant_id]
          @hp_avl_zone  = options[:hp_avl_zone]

          ### Make the authentication call
          if (auth_version == :v2)
            # Call the control services authentication
            credentials = Fog::HP.authenticate_v2(options, @connection_options)
            # the CS service catalog returns the block storage endpoint
            @hp_network_uri = credentials[:endpoint_url]
          else
            # Call the legacy v1.0/v1.1 authentication
            credentials = Fog::HP.authenticate_v1(options, @connection_options)
            # the user sends in the block storage endpoint
            @hp_network_uri = options[:hp_auth_uri]
          end

          @auth_token = credentials[:auth_token]
          @persistent = options[:persistent] || false

          uri = URI.parse(@hp_network_uri)
          @host   = uri.host
          @path   = uri.path
          @port   = uri.port
          @scheme = uri.scheme

          @connection = Fog::Connection.new("#{@scheme}://#{@host}:#{@port}", @persistent, @connection_options)
        end

        def reload
          @connection.reset
        end

        def request(params, parse_json = true, &block)
          begin
            response = @connection.request(params.merge!({
              :headers  => {
                'Content-Type' => 'application/json',
                'Accept'       => 'application/json',
                'X-Auth-Token' => @auth_token
              }.merge!(params[:headers] || {}),
              :host     => @host,
              :path     => "#{@path}/v2.0/#{params[:path]}"
            }), &block)
          rescue Excon::Errors::HTTPStatusError => error
            raise case error
            when Excon::Errors::NotFound
              Fog::HP::Network::NotFound.slurp(error)
            else
              error
            end
          end
          if !response.body.empty? && parse_json && response.headers['Content-Type'] =~ %r{application/json}
            response.body = Fog::JSON.decode(response.body)
          end
          response
        end

      end

    end
  end
end

