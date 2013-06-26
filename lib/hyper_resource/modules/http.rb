require 'faraday'
require 'uri'
require 'json'

module HyperResource::Modules::HTTP

  ## Loads and returns the resource pointed to by +href+.  The returned
  ## resource will be blessed into its "proper" class, if
  ## +self.class.namespace != nil+.
  def get(params=nil)
    self.response = faraday_connection.get do |req|
      req.url(self.href || '')
      req.params = params if params
    end
    finish_up
  end

  def post(params=nil)
    params ||= self.attributes
    self.response = faraday_connection.post do |req|
      req.url(self.href || '')
      req.headers['Content-type'] = 'application/json'
      req.body = params.respond_to?(:to_json) ?
                   params.to_json             :
                   JSON.dump(params)
    end
    finish_up
  end

  def save
    post
  end

  def put(params=nil)
    params ||= self.changed_attributes
    self.response = faraday_connection.put do |req|
      req.url(self.href || '')
      req.headers['Content-type'] = 'application/json'
      req.body = params.respond_to?(:to_json) ?
                   params.to_json             :
                   JSON.dump(params)
    end
    finish_up
  end

  ## Returns a per-thread Faraday connection for this object.
  def faraday_connection(url=nil)
    url ||= self.root
    key = "faraday_connection_#{url}"
    return Thread.current[key] if Thread.current[key]

    fc = Faraday.new(:url => url)
    fc.headers.merge!('User-Agent' => "HyperResource #{HyperResource::VERSION}")
    fc.headers.merge!(self.headers || {})
    if ba=self.auth[:basic]
      fc.basic_auth(*ba)
    end
    Thread.current[key] = fc
  end

private

  def finish_up
    status = self.response.status
    if status / 100 == 2
      self.response_body = JSON.parse(self.response.body)
      self.init_from_response_body
      self.blessed
    elsif status / 100 == 3
      ## TODO redirect logic?
    elsif status / 100 == 4
      raise HyperResource::ClientError, status.to_s
    elsif status / 100 == 5
      raise HyperResource::ServerError, status.to_s
    else ## 1xx? really?
      raise HyperResource::ResponseError, "Got status #{status}, wtf?"
    end
  end

end
