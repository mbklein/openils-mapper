require 'json'

module EDI

class Collection
  include Enumerable
  
  def to_hash
    result = {}
    
    self.each { |child|
      if self[child.name].length > 1 and result[child.name].nil?
        result[child.name] = []
      end
      if child.is_a?(Collection)
        # Data elements first
        hash = child.to_hash
        unless hash.empty?
          if result[child.name].is_a?(Array)
            result[child.name] << hash
          else
            result[child.name] = hash
          end
        end
      else
        unless child.value.nil?
          if result[child.name].is_a?(Array)
            result[child.name] << child.value
          else
            result[child.name] = child.value
          end
        end
      end
      if (result[child.name].is_a?(Array) or result[child.name].is_a?(Hash)) and result[child.name].empty?
        result.delete(child.name)
      end
    }
    
    # Segment groups last
    if self.respond_to?(:children) and (self.children.empty? == false)
      segments = []
      self.children.each { |segment|
        segments << [segment.name, segment.to_hash]
      }
      result[self.sg_name] = segments
    end
    
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
      if message.is_a?(MsgGroup)
        messages += message.to_hash
      else
        messages << {message.name => message.to_hash}
      end
    }
    
    {
      'UNA'            => self.una.to_hash,
      'sender'         => self.header.cS002.d0004,
      'sender_qual'    => self.header.cS002.d0007,
      'recipient'      => self.header.cS003.d0010,
      'recipient_qual' => self.header.cS003.d0007,
      'header'         => [self.header.name, self.header.to_hash],
      'body'           => messages,
      'trailer'        => [self.trailer.name, self.trailer.to_hash]
    }
  end
  
end

class Message
  
  def to_hash
    segments = []
    segments << [self.header.name, self.header.to_hash]
    self.find_all { |segment|
      segment.level < 2
    }.each { |segment| 
      segments << [segment.name, segment.to_hash] 
    }
    segments << [self.trailer.name, self.trailer.to_hash]
    segments
  end
  
end

class MsgGroup
  
  def to_hash
    self.collect { |msg| { msg.name => msg.to_hash } }
  end
  
end

class E::UNA
  def to_hash
    result = {}
    [:ce_sep,:de_sep,:decimal_sign,:esc_char,:rep_sep,:seg_term].each { |field|
      result[field.to_s] = self.send(field).chr
    }
    result
  end
end

end