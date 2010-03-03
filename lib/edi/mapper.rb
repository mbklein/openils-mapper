require 'edi4r'
require 'edi4r/edifact'
begin
  require 'edi4r-tdid'
rescue LoadError
  warn "WARNING: edi4r-tdid not found. Only EDIFACT versions d96a and d01b will be supported!"
end
require 'forwardable'
require 'json'

class String
  
  def chunk(len)
    re = Regexp.new(".{0,#{len.to_i}}")
    self.scan(re).flatten.reject { |chunk| chunk.nil? or chunk.empty? }
  end
  
end

module EDI::E

  class Mapper
    extend Forwardable
    
    attr :message, :ic
    attr_accessor :defaults
#    def_delegators :@ic, :charset, :empty?, :groups_created, :header, 
#      :illegal_charset_pattern, :inspect, :is_iedi?, :messages_created, 
#      :output_mode, :output_mode=, :show_una, :show_una=, :syntax, :to_s, 
#      :to_xml, :to_xml_header, :to_xml_trailer, :trailer, :una, :validate, 
#      :version

    class << self
      def defaults
        @defaults || {}
      end
      
      def defaults=(value)
        unless value.is_a?(Hash)
          raise TypeError, "Mapper defaults must be in the form of a Hash"
        end
        @defaults = value
      end
      
      def map(name,expr = nil,&block)
        register_mapping(name,expr,block)
      end

      def register_mapping(name, expr, proc)
        if segment_handlers.find { |h| h[:name] == name }
          raise NameError, "A pseudo-segment called '#{name}' is already registered"
        end
        if expr.nil?
          expr = Regexp.new("^#{name}$")
        end
        segment_handlers.push({:name => name,:re => expr,:proc => proc})
      end

      def unregister_mapping(name)
        segment_handlers.delete_if { |h|
          h[:name] == name
        }
      end

      def find_mapping(name)
        segment_handlers.find { |h|
          h[:re].match(name)
        }
      end
      
      private
      def segment_handlers
        if @segment_handlers.nil?
          @segment_handlers = []
        end
        @segment_handlers
      end
    end
    
    def apply_mapping(name, value)
      handler = self.class.find_mapping(name)
      if handler.nil?
        raise NameError, "Unknown pseudo-segment: '#{name}'"
      end
      handler[:proc].call(self, name, value)
    end
    
    def self.from_json(json, ic_opts = {})
      struct = JSON.parse(json)

      json_opts = {}
      [:sender,:recipient].each { |party|
        party_info = struct[party.to_s]
        if party_info.is_a?(Hash)
          json_opts[party] = party_info['id']
          json_opts["#{party}_qual".to_sym] = party_info['id-qualifier']
        elsif party_info.is_a?(String)
          (id,qual) = party_info.split(/:/)
          json_opts[party] = id
          json_opts["#{party}_qual".to_sym] = qual
        end
      }
      
      json_msg_opts = {}
      if struct['msg_opts'].is_a?(Hash)
        struct['msg_opts'].each_pair { |k,v| json_msg_opts[k.to_sym] = v }
      end
      
      result = self.new(ic_opts.merge(json_opts))
      
      ['header','trailer'].each { |envseg|
        if struct[envseg]
          target = result.send(envseg.to_sym)
          struct[envseg].last.each_pair { |de,val|
            if val.is_a?(Hash)
              val.each_pair { |cde,sval|
                target[de][0][cde][0].value = sval
              }
            else
              target[de][0].value = val
            end
          }
        end
      }
      
      struct['body'].each { |msg_def|
        msg_def.each_pair { |msg_type, msg_body|
          if unh = msg_body.find { |s| s[0] == 'UNH' }
            version_info = unh[1]['S009']
            json_msg_opts[:resp_agency] = version_info['0051']
            json_msg_opts[:version] = version_info['0052']
            json_msg_opts[:release] = version_info['0054']
          end
          result.add_message(msg_type, json_msg_opts)
          result.add(msg_body)
        }
      }
      result.finalize
    end

    def initialize(ic_opts = {})
      # Bug in edi4r 0.9 -- sometimes :recipient is used; sometimes :recip. It doesn't
      # work. We'll override it.
      local_ic_opts = ic_opts.reject { |k,v| [:sender,:sender_qual,:recipient,:recipient_qual].include?(k) }
      @ic = EDI::E::Interchange.new(local_ic_opts || {})
  
      # Apply any envelope defaults.
      ['UNB','UNZ'].each { |seg|
        seg_defs = self.class.defaults[seg]
        if seg_defs
          seg_defs.each_pair { |cde,defs|
            segment = @ic.header[cde].first
            unless segment.nil?
              defs.each_pair { |de,val|
                segment[de][0].value = val
              }
            end
          }
        end
      }

      @ic.header.cS002.d0004 = ic_opts[:sender] unless ic_opts[:sender].nil?
      @ic.header.cS002.d0007 = ic_opts[:sender_qual] unless ic_opts[:sender_qual].nil?
      @ic.header.cS003.d0010 = ic_opts[:recipient] unless ic_opts[:recipient].nil?
      @ic.header.cS003.d0007 = ic_opts[:recipient_qual] unless ic_opts[:recipient_qual].nil?
    end
    
    def add_message(msg_type, msg_opts = {})
      @message = @ic.new_message( { :msg_type => msg_type, :version => 'D', :release => '96A', :resp_agency => 'UN' }.merge(msg_opts || {}) )
      @ic.add(@message,false)
    end
    
    def add(*args)
      if args[0].is_a?(String)
        while args.length > 0
          add_segment(args.shift, args.shift)
        end
      elsif args.length == 1 and args[0].is_a?(Array)
        add(*args[0])
      else
        args.each { |arg|
          add(arg)
        }
      end
    end
    
    def finalize
      mode = @ic.output_mode
      @ic = EDI::E::Interchange.parse(StringIO.new(@ic.to_s))
      @ic.output_mode = mode
      return self
    end
    
    def to_s
      @ic.to_s
    end
    
    def method_missing(sym, *args)
      if @ic.respond_to?(sym)
        @ic.send(sym, *args)
      else
        super(sym, *args)
      end
    end
    
    private
    def add_segment(seg_name, value)
      if seg_name =~ /^[A-Z]{3}$/
        if seg_name !~ /^UN[HT]$/
          seg = @message.new_segment(seg_name)
          @message.add(seg)
          default = self.class.defaults[seg_name]
          data = default.nil? ? value : default.merge(value)
          data.each_pair { |de,val|
            add_element(seg,de,val,default)
          }
        end
      else
        apply_mapping(seg_name, value)
      end
    end

    def add_element(parent, de, value, default)
      default = default[de] unless default.nil?
      
      if de =~ /^SG[0-9]+$/
        value.each { |v| self.add(*v) }
      elsif value.is_a?(Hash)
        new_parent = parent.send("c#{de}")
        data = default.nil? ? value : default.merge(value)
        data.each_pair { |k,v| add_element(new_parent,k,v,default) }
      elsif value.is_a?(Array)
        de_array = parent.send("a#{de}")
        value.each_with_index { |v,i|
          element = de_array[i]
          if v.is_a?(Hash)
            data = default.nil? ? v : default.merge(v)
            data.each_pair { |k,v1| add_element(element, k, v1, default) }
          else
            element.value = v
          end
        }
      else
        parent.send("d#{de}=",value)
      end
    end
    
  end
  
end