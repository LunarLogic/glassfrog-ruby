require 'glassfrog/base'
require 'glassfrog/rest/get'
require 'glassfrog/rest/post'
require 'glassfrog/rest/patch'
require 'glassfrog/rest/delete'

module Glassfrog
  # 
  # Encapsulates GlassFrog Checklist Items.
  # 
  class ChecklistItem < Glassfrog::Base
    # @return [String]
    attr_accessor :description, :frequency
    # @return [Boolean]
    attr_accessor :global
    # @return [Hash]
    attr_accessor :links
    PATH = '/checklist_items'
    TYPE = :checklist_items

    # 
    # Sends a GET request for ChecklistItem(s) to GlassFrog.
    # @param client [Glassfrog::Client] The client that will send the request. Contains the API key.
    # @param options [Hash, Glassfrog::Base] The options used to find the correct ChecklistItems(s).
    # 
    # @return [Array<Glassfrog::ChecklistItem>] The array of ChecklistItem(s) fetched from GlassFrog.
    def self.get(client, options)
      response = Glassfrog::REST::Get.irregular_get(client, TYPE, PATH, options)
      response[TYPE] ? response[TYPE].map { |object| self.new(object) } : []
    end

    # 
    # Sends a POST request to create a ChecklistItem on GlassFrog.
    # @param client [Glassforg::Client] The client that will send the request. Contains the API key.
    # @param options [Hash, Glassforg::Base] The options used to create the new ChecklistItems.
    # 
    # @return [Array<Glassfrog::ChecklistItem>] The array containing the new ChecklistItem.
    def self.post(client, options)
      response = Glassfrog::REST::Post.post(client, PATH, { TYPE => [parse_options(options)] })
      response[TYPE] ? response[TYPE].map { |object| self.new(object) } : []
    end

    # 
    # Sends a PATCH request to update a ChecklistItem on GlassFrog.
    # @param client [Glassforg::Client] The client that will send the request. Contains the API key.
    # @param identifier [Integer] The ID of the ChecklistItem to be updated.
    # @param options [Hash, Glassfrog::Base] The options used to update the ChecklistItem.
    # 
    # @return [Boolean] Whether the request failed or not.
    def self.patch(client, identifier, options)
      options = Glassfrog::REST::Patch.formify(parse_options(options), self)
      response = Glassfrog::REST::Patch.patch(client, PATH + '/' + identifier.to_s, options)
    end

    # 
    # Sends a DELETE request to delete a ChecklistItem on GlassFrog.
    # @param client [Glassforg::Client] The client that will send the request. Contains the API key.
    # @param options [Hash, Glassfrog::Base] The options containing the ID of the ChecklistItem to delete.
    # 
    # @return [Boolean] Whether the request failed or not.
    def self.delete(client, options)
      path = PATH + '/' + options.delete(:id).to_s
      response = Glassfrog::REST::Delete.delete(client, path, options)
    end

    private

    PARAMS = [
      :description,
      :frequency,
      :global,
      :circle_id,
      :role_id
    ]

    # 
    # Grabs only the parameters accepted by GlassFrog.
    # @param options [Hash] Inputed options.
    # 
    # @return [Hash] Valid GlassFrog options.
    def self.parse_options(options)
      options[:circle_id] = options[:links][:circle] if options[:links] && options[:links][:circle]
      options[:role_id] = options[:links][:role] if options[:links] && options[:links][:role]
      params_hash = Hash.new
      PARAMS.each { |param| params_hash[param] = options[param] if options[param] }
      params_hash
    end
  end
end