module ClientSideValidations

  class Middleware
    IGNORE_PARAMS = %w{case_sensitive id scope}
    def initialize(app)
      @app = app
    end

    def call(env)
      case env['PATH_INFO']
      when '/validators/uniqueness.json'
        request = ActionDispatch::Request.new(env)
        unique = is_unique?(request.params)
        [200, {'Content-Type' => 'application/json', 'Content-Length' => "#{unique.length}"}, [unique]]
      else
        @app.call(env)
      end
    end

    private

    def is_unique?(params)
      resource = extract_resource(params)
      klass = resource.keys.first.classify.constantize
      attribute = resource.first[1].keys.first
      value = resource.first[1][attribute]

      if (defined?(::ActiveRecord::Base) && klass.superclass == ::ActiveRecord::Base)
        middleware_klass = ClientSideValidations::ActiveRecord::Middleware
      elsif (defined?(::Mongoid::Document) && klass.included_modules.include?(::Mongoid::Document))
        middleware_klass = ClientSideValidations::Mongoid::Middleware
      end

      middleware_klass.is_unique?(klass, attribute, value, params)
    end

    def extract_resource(params)
      parent_key = (params.keys - IGNORE_PARAMS).first

      if params[parent_key].is_a?(Hash)
        if resource = extract_resource(params[parent_key])
          resource
        else
          { parent_key => params[parent_key] }
        end
      else
        false
      end
    end
  end

  class Engine < ::Rails::Engine
    config.app_middleware.use ClientSideValidations::Middleware
  end

end

