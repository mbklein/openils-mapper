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
    
    attr :message
    attr_accessor :defaults
    def_delegators :@ic, :charset, :empty?, :groups_created, :header, 
      :illegal_charset_pattern, :inspect, :is_iedi?, :messages_created, 
      :output_mode, :output_mode=, :show_una, :show_una=, :syntax, :to_s, 
      :to_xml, :to_xml_header, :to_xml_trailer, :trailer, :una, :validate, 
      :version
    
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
    
    def self.from_json(msg_type, json, msg_opts = {}, ic_opts = {})
      result = self.new(msg_type, msg_opts, ic_opts)
      result.add(JSON.parse(json))
      result.finalize
    end

    def initialize(msg_type, msg_opts = {}, ic_opts = {})
      @ic = EDI::E::Interchange.new(ic_opts || {})
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
    
    private
    def add_segment(seg_name, value)
      if seg_name =~ /^[A-Z]{3}$/
        seg = @message.new_segment(seg_name)
        @message.add(seg)
        default = self.class.defaults[seg_name]
        data = default.nil? ? value : default.merge(value)
        data.each_pair { |de,val|
          add_element(seg,de,val,default)
        }
      else
        apply_mapping(seg_name, value)
      end
    end

    def add_element(parent, de, value, default)
      default = default[de] unless default.nil?
      
      if value.is_a?(Hash)
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