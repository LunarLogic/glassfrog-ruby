require 'http'
require 'tmpdir'
require 'glassfrog/utils/utils'
require 'glassfrog/utils/graph'
require 'glassfrog/action'
require 'glassfrog/checklist_item'
require 'glassfrog/circle'
require 'glassfrog/metric'
require 'glassfrog/person'
require 'glassfrog/project'
require 'glassfrog/role'
require 'glassfrog/trigger'

module Glassfrog
  # 
  # Encapsulates HTTP/GlassFrog message sending.
  # 
  class Client
    include Glassfrog::Utils
    # @return [String]
    attr_accessor :api_key
    # @return [HTTP]
    attr_reader :http
    # @return [Boolean]
    attr_reader :caching
    # @return [Hash]
    attr_reader :caching_settings
    # @return [TempFile]
    attr_reader :cache_meta, :cache_entity
    CACHE = 'glassfrog-cache-'

    TYPES = {
              action: Glassfrog::Action,
      checklist_item: Glassfrog::ChecklistItem,
              circle: Glassfrog::Circle,
              metric: Glassfrog::Metric,
              person: Glassfrog::Person,
             project: Glassfrog::Project,
                role: Glassfrog::Role,
             trigger: Glassfrog::Trigger
    }

    TYPES.merge!({
              actions: TYPES[:action],
      checklist_items: TYPES[:checklist_item],
              circles: TYPES[:circle],
              metrics: TYPES[:metric],
               people: TYPES[:person],
             projects: TYPES[:project],
                roles: TYPES[:role],
             triggers: TYPES[:trigger]
    })

    ASSOCIATED_PARAMS = {
      Glassfrog::Role => {
        Glassfrog::Circle =>  [:circle_id, :id],
        Glassfrog::Person =>  [:person_id, :id]
        },
      Glassfrog::Person => {
        Glassfrog::Circle =>  [:circle_id, :id],
          Glassfrog::Role =>  [:role, :name]
        },
      Glassfrog::Project => {
        Glassfrog::Circle =>  [:circle_id, :id],
        Glassfrog::Person =>  [:person_id, :id]
        },
      Glassfrog::Metric => {
        Glassfrog::Circle =>  [:circle_id, :id],
          Glassfrog::Role =>  [:role_id, :id]
        },
      Glassfrog::ChecklistItem => {
        Glassfrog::Circle =>  [:circle_id, :id]
        },
      Glassfrog::Action => {
        Glassfrog::Person =>  [:person_id, :id],
        Glassfrog::Circle =>  [:circle_id, :id]
        },
      Glassfrog::Trigger => {
        Glassfrog::Person =>  [:person_id, :id],
        Glassfrog::Circle =>  [:circle_id, :id]
      }
    }

    # 
    # Initializes a new Client object.
    # @param attrs={} [Hash, String] Either just the API key, or a Hash of options.
    # 
    # @return [Glassfrog::Client] The initialized Client object.
    def initialize(attrs={})
      if attrs.class == String
        @api_key = attrs
      elsif attrs.class == Hash
        attrs.each do |key, value|
          instance_variable_set("@#{key}", value)
        end
      else
        raise(ArgumentError, 'Invalid Arguements. Must be String or Hash.')
      end
      yield(self) if block_given?
      @caching ||= nil
      @caching = @caching || (@caching.nil? && @caching_settings)
      tmpdir = @caching ? setup_cache : nil
      ObjectSpace.define_finalizer(self, self.class.finalize(tmpdir)) if tmpdir
      @http = @caching ? HTTP.cache({ metastore: @cache_meta, entitystore: @cache_entity }) : HTTP
    end

    # 
    # Sends a GET request to the corresponding object type.
    # @param type [Glassfrog::Base] Object type to send request to.
    # @param options={} [Hash, Glassfrog::Base, Integer, String, URI] Options to specify object(s) to fetch.
    # 
    # @return [Array<Glassfrog::Base>] The fetched object(s).
    def get(type, options={})
      klass = TYPES[parameterize(type)]
      options = parse_params(options, klass)
      klass.public_send(:get, self, options)
    end

    # 
    # Sends a POST request to the corresponding object type.
    # @param type [Glassfrog::Base] Object type to send request to.
    # @param options={} [Hash, Glassfrog::Base] Options to specify attribute(s) of object being created.
    # 
    # @return [Array<Glassfrog::Base>] The created object.
    def post(type, options)
      klass = TYPES[parameterize(type)]
      options = validate_options(options, klass)
      klass.public_send(:post, self, options)
    end

    # 
    # Sends a PATCH request to the corresponding object type.
    # @param type [Glassfrog::Base] Object type to send request to.
    # @param identifier=nil [Integer] The ID of the object to update.
    # @param options={} [Hash, Glassfrog::Base] Options to specify attribute(s) to update and/or ID.
    # 
    # @return [Hash, Glassfrog::Base, Integer, String, URI, Boolean] The options passed if successful or false if unsuccessful.
    def patch(type, identifier=nil, options)
      klass = TYPES[parameterize(type)]
      identifier = extract_id(options, klass) if identifier.nil?
      raise(ArgumentError, "No valid id found given in options") if identifier.nil?
      options = validate_options(options, klass)
      if klass.public_send(:patch, self, identifier, options) then options else false end
    end

    # 
    # Sends a DELETE request to the corresponding object type.
    # @param type [Glassfrog::Base] Object type to send request to.
    # @param options={} [Hash, Glassfrog::Base, Integer, String, URI] Options to specify the ID of the object to delete.
    # 
    # @return [Boolean] Whether the request was successful.
    def delete(type, options)
      klass = TYPES[parameterize(type)]
      identifier = extract_id(options, klass)
      raise(ArgumentError, "No valid id found given in options") unless identifier
      if klass.public_send(:delete, self, { id: identifier }) then true else false end
    end

    # 
    # Builds the organization's circle hierarchy.
    # @param circles=nil [Array<Glassfrog::Circle>] Array of circle objects (used instead of a GET request).
    # @param roles=nil [Array<Glassfrog::Role>] Array of role objects (used instead of a GET request).
    # 
    # @return [Glassfrog::Circle] The root circle.
    def build_hierarchy(circles=nil, roles=nil)
      Glassfrog::Graph.hierarchy(self, circles, roles)
    end

    # 
    # Find the root circle of an array of circles.
    # @param circles=nil [Array<Glassfrog::Circle>] Array of circle objects of which the root will be found.
    # @param roles=nil [Array<Glassfrog::Role>] Array of role objects to use to find supporting role of the root circle.
    # 
    # @return [Glassfrog::Circle] The root circle.
    def find_root(circles=nil, roles=nil)
      circles ||= self.get :circles
      roles ||= self.get :roles
      Glassfrog::Graph.root(circles, roles)
    end

    # 
    # Gets the HTTP headers for requests.
    # 
    # @return [Hash] The headers.
    def headers
      { 'X-Auth-Token' => self.api_key }
    end

    # 
    # Checks if there is an API Key.
    # 
    # @return [Boolean] Whether there is an API Key.
    def api_key?
      !!(api_key)
    end

    # 
    # Allow @caching to be set only once. Otherwise throw error.
    # @param value [Boolean] Whether caching should be on or off.
    # 
    # @return [Boolean] The value.
    def caching=(value)
      defined?(@caching) ? raise(ArgumentError, "Caching is already set.") : @caching = value
    end

    # 
    # Allow @caching_settings to be set only once. Otherwise throw error.
    # @param value [Hash] The caching settings.
    # 
    # @return [Hash] The settings that have been set.
    def caching_settings=(value)
      defined?(@caching_settings) ? raise(ArgumentError, "Caching Settings are already set.") : @caching_settings = value
    end

    # 
    # Garbage collection finalizer for the cache directory; if a cache directory was created it will be deleted with the Client object.
    # @param tmpdir [String] Path to the temporary directory.
    # 
    # @return [Proc] Proc containing the directory deletion.
    def self.finalize(tmpdir)
      proc { FileUtils.remove_entry(tmpdir) }
    end

    private

    # 
    # Parses the meta and entity store locations or sets to the defaults (temporary files).
    # 
    # @return [String] If a temporary cache directory was created, returns that path string (or nil).
    def setup_cache
      @caching_settings ||= {}
      @cache_tmpdir ||= Dir.mktmpdir(CACHE) unless @caching_settings[:metastore]
      @cache_meta = @caching_settings[:metastore] || ('file:' + @cache_tmpdir + '/meta')
      @cache_tmpdir ||= Dir.mktmpdir(CACHE) unless @caching_settings[:entitystore]
      @cache_entity = @caching_settings[:entitystore] || ('file:' + @cache_tmpdir + '/entity')
      @cache_tmpdir || nil
    end

    # 
    # Extracts the ID from options and validates the options before a request.
    # @param options [Hash, Glassfrog::Base, Integer, String, URI] Options passed to the request.
    # @param klass [Class] The class of the object being targeted.
    # 
    # @return [Hash] The parameters to pass to the request.
    def parse_params(options, klass)
      options = symbolize_keys(options)
      id = extract_id(options, klass)
      params = id ? { id: id } : parse_associated_params(options, klass)
      validate_params(params, klass)
    end

    # 
    # Checks if an associated object was passed as options.
    # @param options [Hash, Glassfrog::Base, Integer, String, URI] Options passed to the request.
    # @param klass [Class] The class of the object being targeted.
    # 
    # @return [Hash, Glassfrog::Base, Integer, String, URI] The associated object parameter in a hash or options.
    def parse_associated_params(options, klass)
      associated_param = ASSOCIATED_PARAMS[klass] && ASSOCIATED_PARAMS[klass][options.class] ? ASSOCIATED_PARAMS[klass][options.class] : nil
      if associated_param
        key, method = associated_param
        method == :name ? { key => parameterize(options.public_send(method)) } : { key => options.public_send(method) }
      else 
        options
      end
    end

    # 
    # Checks if options are valid.
    # @param options [Hash, Glassfrog::Base, Integer, String, URI] Options passed to the request.
    # @param klass [Class] The class of the object being targeted.
    # 
    # @return [Hash, Integer, String, URI] If valid options, if invalid raises error.
    def validate_options(options, klass)
      raise(ArgumentError, "Options cannot be " + options.class.name) unless options.is_a?(klass) || options.is_a?(Hash)
      options.is_a?(Glassfrog::Base) ? options.hashify : options
    end

    # 
    # Checks if options are valid or if they are an associated object.
    # @param params [Hash, Glassfrog::Base, Integer, String, URI] Options passed to the request.
    # @param klass [Class] The class of the object being targeted.
    # 
    # @return [Hash, Integer, String, URI] If valid params, if invalid raises error.
    def validate_params(params, klass)
      raise(ArgumentError, "Options cannot be " + params.class.name) unless params.is_a?(klass) || params.is_a?(Hash) || 
        (ASSOCIATED_PARAMS[klass] && ASSOCIATED_PARAMS[klass].keys.include?(params.class))
      params.is_a?(Glassfrog::Base) ? params.hashify : params
    end
  end
end