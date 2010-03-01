require 'openils/mapper'

describe OpenILS::Mapper do
  
  before(:each) do
    @map = OpenILS::Mapper.new('ORDERS')
  end
  
  it "should add both qualified and unqualified buyer/vendor fields" do
    @map.add(
      ['buyer', { 'id' => '3472205', 'id-qualifier' => '91', 'reference' => { 'API' => '3472205 0001' } }],
      ['buyer', { 'id' => '3472205', 'reference' => { 'API' => '3472205 0001' }}]
    )
    @map.add(
      'vendor', '1556150', 
      'vendor', { 'id' => '1556150', 'id-qualifier' => '91', 'reference' => { 'IA' => '1865' }}
    )
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'NAD+BY+3472205::91'RFF+API:3472205 0001'NAD+BY+3472205::31B'RFF+API:3472205 0001'NAD+SU+1556150::31B'NAD+SU+1556150::91'RFF+IA:1865'UNT+9+1'"
  end
  
  it "should properly chunk and add descriptive fields" do
    @map.add(
      'desc', [
        'BAU', 'Campbell, James',
        'BTI', "The Ghost Mountain boys : their epic march and the terrifying battle for New Guinea -- the forgotten war of the South Pacific",
        'BPU', 'Crown Publishers',
        'BPD', 2007
      ]
    )
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'IMD+F+BAU+:::Campbell, James'IMD+F+BTI+:::The Ghost Mountain boys ?: their epi:c march and the terrifying battle f'IMD+F+BTI+:::or New Guinea -- the forgotten war :of the South Pacific'IMD+F+BPU+:::Crown Publishers'IMD+F+BPD+:::2007'UNT+7+1'"
  end

  it "should create a message from high-level JEDI input" do
    json = File.read(File.join(File.dirname(__FILE__), 'test_po.json'))
    @map = OpenILS::Mapper.from_json(%{{ "msg_type": "ORDERS", "msg": #{json}, "sender": "123456", "recipient": {"id": "999999999", "id-qualifier": "1"}}})
    @map.message.to_s.should == "UNH+1+ORDERS:D:96A:UN'BGM+220+2+9'DTM+137:20090331:102'NAD+BY+3472205::91'RFF+API:3472205 0001'NAD+BY+3472205::31B'RFF+API:3472205 0001'NAD+SU+1556150::31B'NAD+SU+1556150::91'RFF+IA:1865'CUX+2:USD:9'LIN+1'PIA+5+03-0010837:SA'IMD+F+BTI+:::Discernment'IMD+F+BPU+:::Concord Records,'IMD+F+BPD+:::1986.'IMD+F+BPH+:::1 sound disc ?:'QTY+21:2'PRI+AAB:35.95'RFF+LI:2/1'LIN+2'PIA+5+03-0010840:SA'IMD+F+BTI+:::The inner source'IMD+F+BAU+:::Duke, George, 1946-'IMD+F+BPU+:::MPS Records,'IMD+F+BPD+:::1973.'IMD+F+BPH+:::2 sound discs ?:'QTY+21:1'PRI+AAB:28.95'RFF+LI:2/2'UNS+S'CNT+2:2'UNT+33+1'"
    @map.header.cS002.to_s.should == "123456:31B"
    @map.header.cS003.to_s.should == "999999999:1"
  end
  
end