class Object
  def try(method, *args, &block)
    return unless respond_to? method
    public_send(method, *args, &block)
  end
end

class NilClass
  def try(*args, &block)
    self
  end
end