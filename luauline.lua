local HLIST = node.id("hlist")
local VLIST = node.id("vlist")
local RULE = node.id("rule")
local GLUE = node.id("glue")
local GLUESPEC = node.id("glue_spec")
local KERN = node.id("kern")
local WHAT = node.id("whatsit")
local USER = node.subtype("user_defined")

function string.starts(String,Start)
  return string.sub(String,1,string.len(Start)) == Start
end

local check_whatsit_user_string = function(item)
  if item.id == WHAT and item.subtype == USER and item.type == 115 then
    return true
  end
  return false
end

create_user_node = function(data)
  local temp_user_node = node.new(WHAT, USER)
  temp_user_node.type = 115
  temp_user_node.value = data
  node.write(temp_user_node)
end

create_user_rule_node = function(depth, height)
  local temp_user_node = node.new(WHAT, USER)
  local temp_rule_node = node.new(RULE)
  temp_rule_node.height = -tex.sp(depth)
  temp_rule_node.depth = tex.sp(depth) + tex.sp(height)
  temp_user_node.type = 110
  temp_user_node.value = node.copy(temp_rule_node)
  node.write(temp_user_node)
end

create_user_leaders_node = function()
  local temp_user_node = node.new(WHAT, USER)
  local item_leader = node.new(GLUE)
  local item_leader_spec = node.new(GLUESPEC)
  item_leader_spec.width, item_leader_spec.stretch, item_leader_spec.shrink = 0, 0, 0
  item_leader.spec = item_leader_spec
  item_leader.subtype = 101
  item_leader.leader = node.copy(tex.getbox("lua@underline@box"))
  temp_user_node.type = 110
  temp_user_node.value = node.copy(item_leader)
  node.write(temp_user_node)
end

create_user_hlist_node = function()
  local temp_user_node =node.new(WHAT, USER)
  temp_user_node.type = 110
  temp_user_node.value = node.copy(tex.getbox("lua@underline@box"))
  node.write(temp_user_node)
end

local get_instances
get_instances = function (head, prefix, separator)
  local current_instances = { }
  for line in node.traverse(head) do
    local item = line.head
    while item do
      if check_whatsit_user_string(item) and string.starts(item.value, prefix .. separator) then
        local current_instance = { }
        table.insert(current_instance, string.sub(item.value,string.len(prefix)+string.len(separator)+1))
        item = item.next
        table.insert(current_instance, item.value)
        table.insert(current_instances, current_instance)
      elseif item.id == HLIST or item.id == VLIST then
        for _,entry in ipairs(get_instances(item, prefix, separator)) do
          table.insert(current_instances, entry)
        end
      end
      item = item.next
    end
  end
  return current_instances
end

local good_item = function(item)
  if item.id == GLUE and (item.subtype == 8 or item.subtype == 9 or item.subtype == 15) then
    return false
  else
    return true
  end
end

local insert_single_underline = function (head, ratio, sign, order, item, end_node, action)
  local temp_width = node.dimensions(ratio, sign, order, item, end_node.next)
  local new_item = nil
  if action.id == RULE then
    new_item = node.new(RULE)
    new_item.depth = action.depth
    new_item.height = action.height
    new_item.width = temp_width
  elseif action.id == HLIST then
    new_item = node.new(HLIST)
    new_item = node.copy(action)
    new_item.width = temp_width/2
    temp_width = temp_width/2
  elseif action.id == GLUE then
    new_item = node.new(GLUE)
    new_item_spec = node.new(GLUESPEC)
    new_item_spec.width, new_item_spec.stretch, new_item_spec.shrink = temp_width, 0, 0
    new_item.spec = new_item_spec
    new_item.subtype = 101
    new_item.leader = node.copy(action.leader)
  end
  local item_kern = node.new(KERN, 1)
  item_kern.kern = -temp_width
  node.insert_after(head, end_node, item_kern)
  node.insert_after(head, item_kern, new_item)
  return new_item
end

local underline
underline = function (head, order, ratio, sign, index, action, cont)
  local newcontinue = false
  local item = head
  while item do
    if item.id == HLIST or item.id == VLIST then
      newcontinue = underline(item.head, item.glue_order, item.glue_set, item.glue_sign, index, action, cont)
      item = item.next
    elseif cont or ( check_whatsit_user_string(item) and string.starts(item.value,"lua@underline@start@" .. index) ) then
      if check_whatsit_user_string(item) and string.starts(item.value,"lua@underline@start@" .. index) then
        node.remove(head, item)
      end
      cont = false
      local end_node = item
      while end_node.next and not ( check_whatsit_user_string(end_node.next) and string.starts(end_node.next.value, "lua@underline@stop@" .. index) ) and good_item(end_node.next) do
        end_node = end_node.next
      end
      if not ( check_whatsit_user_string(end_node.next) and string.starts(end_node.next.value, "lua@underline@stop@" .. index) ) then
        newcontinue = true
      else
        node.remove(head, end_node.next)
      end
      new_item = insert_single_underline(head, ratio, sign, order, item, end_node, action)
      item = new_item.next
    else
      item = item.next
    end
  end
  return newcontinue
end

local get_lines = function (head)
  local continue = false
  for _,entry in ipairs(get_instances(head, "lua@underline@start", "@")) do
    for line in node.traverse_id(HLIST, head) do
      continue = underline(line.head, line.glue_order, line.glue_set, line.glue_sign, entry[1], entry[2], continue)
    end
  end
  return head
end

luatexbase.add_to_callback("post_linebreak_filter", get_lines, "underline")
