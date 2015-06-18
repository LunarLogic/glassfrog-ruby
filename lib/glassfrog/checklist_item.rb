require 'glassfrog/rest/get'
require 'glassfrog/rest/post'
require 'glassfrog/rest/patch'
require 'glassfrog/rest/delete'

module Glassfrog
  class ChecklistItem
    attr_accessor :id, :description, :frequency, :global, :links

    def self.get(client, options)
      response = Glassfrog::REST::Get.get(client, '/checklist_items', options)
    end

    def self.post(client, options)
      response = Glassfrog::REST::Post.post(client, '/checklist_items', options)
    end

    def self.patch(client, options)
      response = Glassfrog::REST::Patch.patch(client, '/checklist_items', options)
    end

    def self.delete(client, options)
      response = Glassfrog::REST::Delete.delete(client, '/checklist_items', options)
    end

    def initialize(attrs = {})
      attrs.each do |key, value|
        instance_variable_set("@#{key}", value);
      end
      yield(self) if block_given?
    end
  end
end