# map_spec.rb
require 'edi/mapper'

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
  
end