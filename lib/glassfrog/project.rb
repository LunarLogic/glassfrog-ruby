require 'glassfrog/rest/get'
require 'glassfrog/rest/post'
require 'glassfrog/rest/patch'
require 'glassfrog/rest/delete'

module Glassfrog
  class Project
    attr_accessor :id, :description, :status, :link, :value, :effort, :roi, 
                  :private_to_circle, :created_at, :archived_at, :links

    def self.get(options)
      response = Glassfrog::REST::Get.get('/projects', options)
    end

    def self.post(options)
      response = Glassfrog::REST::Post.post('/projects', options)
    end

    def self.patch(options)
      response = Glassfrog::REST::Patch.patch('/projects', options)
    end

    def self.delete(options)
      response = Glassfrog::REST::Delete.delete('/projects', options)
    end

    def initialize(attrs = {})
      attrs.each do |key, value|
        instance_variable_set("@#{key}", value);
      end
      yield(self) if block_given?
    end
  end
end