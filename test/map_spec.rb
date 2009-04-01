# map_spec.rb
require 'edi/mapper'
require 'edi/edi2json'

describe EDI::E::Mapper do
  
  before(:each) do
    @map = EDI::E::Mapper.new('ORDERS')
  end
  
  it "should chunk text" do
    s = 'abcdefghijklmnopqrstuvwxyz'
    s.chunk(5).should == ['abcde','fghij','klmno','pqrst','uvwxy','z']
  end

  it "should produce an empty purchase order when initialized" do
    ic_text = @map.to_s
    ic_text.should_not be_nil
    ic_text.should_not be_empty
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'UNT+2+1'"
  end
  
  it "should add a single segment in tuple form" do
    @map.add("BGM", {"1225" => 9,"C002" => {"1001" => 220},"1004" => "12345678"})
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'BGM+220+12345678+9'UNT+3+1'"
  end

  it "should properly apply defaults" do
    old_defaults = EDI::E::Mapper.defaults
    EDI::E::Mapper.defaults = {
      'BGM' => { 'C002' => { '1001' => 220 }, '1225' => 9 }
    }
    @map.add("BGM", {"1004" => "12345678"})
    EDI::E::Mapper.defaults = old_defaults
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'BGM+220+12345678+9'UNT+3+1'"
  end

  it "should raise an exception if defaults don't look right" do
    lambda {
      EDI::E::Mapper.defaults = 'This is wrong!'
    }.should raise_error(TypeError)
  end
  
  it "should add multiple elements in tuple form" do
    @map.add(
      'BGM', { 'C002' => { '1001' => 220 }, '1004' => '12345678', '1225' => 9 },
      'DTM', { 'C507' => { '2005' => 137, '2380' => '20090101', '2379' => 102 }}
    )
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'BGM+220+12345678+9'DTM+137:20090101:102'UNT+4+1'"
  end
  
  it "should add a single element in array form" do
    @map.add(["BGM", {"1225" => 9,"C002" => {"1001" => 220},"1004" => "12345678"}])
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'BGM+220+12345678+9'UNT+3+1'"
  end
  
  it "should add multiple elements in array form" do
    @map.add(
      ['BGM', { 'C002' => { '1001' => 220 }, '1004' => '12345678', '1225' => 9 }],
      ['DTM', { 'C507' => { '2005' => 137, '2380' => '20090101', '2379' => 102 }}]
    )
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'BGM+220+12345678+9'DTM+137:20090101:102'UNT+4+1'"
  end
  
  it "should make use of custom mappings" do
    EDI::E::Mapper.map 'currency' do |mapper,key,value|
      mapper.add('CUX', { 'C504' => [{ '6347' => 2, '6345' => value, '6343' => 9 }]})
    end

    @map.add(
      'BGM', { 'C002' => { '1001' => 220 }, '1004' => '12345678', '1225' => 9 },
      'DTM', { 'C507' => { '2005' => 137, '2380' => '20090101', '2379' => 102 }},
      'currency', 'USD'
    )
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'BGM+220+12345678+9'DTM+137:20090101:102'CUX+2:USD:9'UNT+5+1'"
  end
  
  it "should raise an exception when an unknown mapping is called" do
    lambda {
      @map.add('everything', { 'answer' => 42 })
    }.should raise_error(NameError)
  end

  it "should raise an exception when re-registering a named mapping" do
    lambda {
      EDI::E::Mapper.map 'currency' do |mapper,key,value|
        mapper.add('CUX', { 'C504' => [{ '6347' => 2, '6345' => value, '6343' => 9 }]})
      end
    }.should raise_error(NameError)
  end
  
  it "should correctly unregister a mapping" do
    EDI::E::Mapper.unregister_mapping 'currency'

    lambda {
      @map.add(
        'BGM', { 'C002' => { '1001' => 220 }, '1004' => '12345678', '1225' => 9 },
        'DTM', { 'C507' => { '2005' => 137, '2380' => '20090101', '2379' => 102 }},
        'currency', 'USD'
      )
    }.should raise_error(NameError)
  end
  
  it "should correctly generate a low-level JEDI hash from an EDIFACT message" do
    interchange = File.open(File.join(File.dirname(__FILE__), 'test_po.edi')) { |f|
      EDI::E::Interchange.parse(f)
    }
    # Can't compare everything because of timestamping, so we'll just compare
    # the bodies for a high degree of confidence
    interchange.to_hash['body'].should == [["ORDERS", {"trailer"=>["UNT", {"0074"=>33, "0062"=>"1"}], "body"=>[["BGM", {"C002"=>{"1001"=>"220"}, "1225"=>"9", "1004"=>"2"}], ["DTM", {"C507"=>{"2005"=>"137", "2380"=>"20090331", "2379"=>"102"}}], ["NAD", {"C082"=>{"3039"=>"3472205", "3055"=>"91"}, "SG2"=>[["RFF", {"C506"=>{"1153"=>"API", "1154"=>"3472205 0001"}}]], "3035"=>"BY"}], ["NAD", {"C082"=>{"3039"=>"3472205", "3055"=>"31B"}, "SG2"=>[["RFF", {"C506"=>{"1153"=>"API", "1154"=>"3472205 0001"}}]], "3035"=>"BY"}], ["NAD", {"C082"=>{"3039"=>"1556150", "3055"=>"31B"}, "3035"=>"SU"}], ["NAD", {"C082"=>{"3039"=>"1556150", "3055"=>"91"}, "SG2"=>[["RFF", {"C506"=>{"1153"=>"IA", "1154"=>"1865"}}]], "3035"=>"SU"}], ["CUX", {"C504"=>{"6345"=>"USD", "6347"=>"2", "6343"=>"9"}}], ["LIN", {"SG25"=>[["PIA", {"C212"=>{"7140"=>"03-0010837", "7143"=>"SA"}, "4347"=>"5"}], ["IMD", {"C273"=>{"7008"=>"Discernment"}, "7077"=>"F", "7081"=>"BTI"}], ["IMD", {"C273"=>{"7008"=>"Concord Records,"}, "7077"=>"F", "7081"=>"BPU"}], ["IMD", {"C273"=>{"7008"=>"1986."}, "7077"=>"F", "7081"=>"BPD"}], ["IMD", {"C273"=>{"7008"=>"1 sound disc :"}, "7077"=>"F", "7081"=>"BPH"}], ["QTY", {"C186"=>{"6060"=>2, "6063"=>"21"}}], ["PRI", {"C509"=>{"5125"=>"AAB", "5118"=>35.95}}], ["RFF", {"C506"=>{"1153"=>"LI", "1154"=>"2/1"}}]], "1082"=>1}], ["LIN", {"SG25"=>[["PIA", {"C212"=>{"7140"=>"03-0010840", "7143"=>"SA"}, "4347"=>"5"}], ["IMD", {"C273"=>{"7008"=>"The inner source"}, "7077"=>"F", "7081"=>"BTI"}], ["IMD", {"C273"=>{"7008"=>"Duke, George, 1946-"}, "7077"=>"F", "7081"=>"BAU"}], ["IMD", {"C273"=>{"7008"=>"MPS Records,"}, "7077"=>"F", "7081"=>"BPU"}], ["IMD", {"C273"=>{"7008"=>"1973."}, "7077"=>"F", "7081"=>"BPD"}], ["IMD", {"C273"=>{"7008"=>"2 sound discs :"}, "7077"=>"F", "7081"=>"BPH"}], ["QTY", {"C186"=>{"6060"=>1, "6063"=>"21"}}], ["PRI", {"C509"=>{"5125"=>"AAB", "5118"=>28.95}}], ["RFF", {"C506"=>{"1153"=>"LI", "1154"=>"2/2"}}]], "1082"=>2}], ["UNS", {"0081"=>"S"}], ["CNT", {"C270"=>{"6069"=>"2", "6066"=>2}}], ["UNT", {"0074"=>33, "0062"=>"1"}]], "header"=>["UNH", {"S009"=>{"0052"=>"D", "0065"=>"ORDERS", "0054"=>"96A", "0051"=>"UN"}, "0062"=>"1"}]}]]
  end

end