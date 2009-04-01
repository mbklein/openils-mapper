require 'json'

module EDI

class Collection
  include Enumerable
  
  def to_hash
    result = {}
    
    self.each { |child|
      if child.is_a?(Collection)
        hash = child.to_hash
        result[child.name] = hash unless hash.empty?
        unless self.children.empty?
          segments = []
          self.children.each { |segment|
            segments << [segment.name, segment.to_hash]
          }
          result[self.sg_name] = segments
        end
      else
        unless child.value.nil?
          result[child.name] = child.value
        end
      end
    }
    result
  end
  
  def to_json(*a)
    self.to_hash.to_json(*a)
  end
  
end

class Interchange
  
  def to_hash
    
    messages = []
    self.each { |message|
      messages << [message.name, message.to_hash]
    }
    
    {
      'UNA' => self.una.to_s,
      'header' => [self.header.name, self.header.to_hash],
      'body' => messages,
      'trailer' => [self.trailer.name, self.trailer.to_hash]
    }
  end
  
end

class Message
  
  def to_hash
    segments = []
    
    self.find_all { |segment|
      segment.level < 2
    }.each { |segment| 
      segments << [segment.name, segment.to_hash] 
    }
    segments << [self.trailer.name, self.trailer.to_hash]
    {
      'header' => [self.header.name, self.header.to_hash],
      'body' => segments,
      'trailer' => [self.trailer.name, self.trailer.to_hash]
    }
  end
  
end

end