class Jets::Resource
  class Base
    extend Memoist
    delegate :logical_id, :type, :properties, :attributes, :parameters, :outputs,
             to: :resource

    # Usually overridden
    def resource
      Jets::Resource.new(definition, replacements)
    end
    memoize :resource

    def replacements
      {}
    end
  end
end
