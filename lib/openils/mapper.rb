require 'edi/mapper'

module OpenILS
  
  class Mapper < EDI::E::Mapper
  end
  
end

OpenILS::Mapper.defaults = {
  'BGM' => { 'C002' => { '1001' => 220 }, '1225' => 9 },
  'DTM' => { 'C507' => { '2005' => 137, '2379' => 102 } },
  'NAD' => { 'C082' => { '3055' => '31B' } },
  'CUX' => { 'C504' => { '6347' => 2, '6345' => 'USD', '6343' => 9 } },
  'LIN' => { 'C212' => { '7143' => 'EN' } },
  'PIA' => { '4347' => 5, 'C212' => { '7143' => 'IB' } },
  'IMD' => { '7077' => 'F' },
  'PRI' => { 'C509' => { '5125' => 'AAB' } },
  'QTY' => { 'C186' => { '6063' => 21 } },
  'UNS' => { '0081' => 'S' },
  'CNT' => { 'C270' => { '6069' => 2 } }
}

OpenILS::Mapper.map 'order' do |mapper,key,value|
  mapper.add('BGM', { '1004' => value['po_number'] })
  mapper.add('DTM', { 'C507' => { '2380' => value['date'] } })
  value['buyer'].to_a.each { |buyer| mapper.add('buyer',buyer) }
  value['vendor'].to_a.each { |vendor| mapper.add('vendor',vendor) }
  mapper.add('currency',value['currency'])
  value['items'].each_with_index { |item,index|
    item['line_index'] = index + 1
    item['line_number'] = "#{value['po_number']}/#{index+1}" if item['line_number'].nil?
    mapper.add('item', item)
  }
  mapper.add("UNS", {})
  mapper.add("CNT", { 'C270' => { '6066' => value['line_items'] } })
end

OpenILS::Mapper.map 'item' do |mapper,key,value|
  mapper.add('LIN', { 'C212' => { '7143' => nil }, '1082' => value['line_index'] })

  # use Array#inject() to group the identifiers in groups of 5.
  # Same as Array#in_groups_of() without the active_support dependency. 
  id_groups = value['identifiers'].inject([[]]) { |result,id|
    result.last << id
    if result.last.length == 5
      result << []
    end
    result
  }
  
  id_groups.each { |group|
    ids = group.compact.collect { |data| 
      id = { '7140' => data['id'] }
      if data['id-qualifier']
        id['7143'] = data['id-qualifier']
      end
      id
    }
    mapper.add('PIA',{ 'C212' => ids })
  }
  value['desc'].each { |desc| mapper.add('desc',desc) }
  mapper.add('QTY', { 'C186' => { '6060' => value['quantity'] } })
  mapper.add('PRI', { 'C509' => { '5118' => value['price'] } })
  mapper.add('RFF', { 'C506' => { '1153' => 'LI', '1154' => value['line_number'] } })
end

OpenILS::Mapper.map('party',/^(buyer|vendor)$/) do |mapper,key,value|
  codes = { 'buyer' => 'BY', 'supplier' => 'SU', 'vendor' => 'SU' }
  party_code = codes[key]
  
  if value.is_a?(String)
    value = { 'id' => value }
  end

  data = { 
    '3035' => party_code, 
    'C082' => { 
      '3039' => value['id']
    }
  }
  data['C082']['3055'] = value['id-qualifier'] unless value['id-qualifier'].nil?
  mapper.add('NAD', data)

  if value['reference']
    value['reference'].each_pair { |k,v|
      mapper.add('RFF', { 'C506' => { '1153' => k, '1154' => v }})
    }
  end
end

OpenILS::Mapper.map 'currency' do |mapper,key,value|
  mapper.add('CUX', { 'C504' => ['6345' => value]})
end

OpenILS::Mapper.map 'desc' do |mapper,key,value|
  values = value.to_a.flatten
  while values.length > 0
    code = values.shift
    text = values.shift.to_s
    code_qual = code =~ /^[0-9]+$/ ? 'L' : 'F'
    chunked_text = text.chunk(35)
    while chunked_text.length > 0
      data = [chunked_text.shift,chunked_text.shift].compact
      mapper.add('IMD', { '7077' => code_qual, '7081' => code, 'C273' => { '7008' => data } })
    end
  end
end