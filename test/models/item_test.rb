require 'test_helper'

class ItemTest < ActiveSupport::TestCase
  def setup
    @todo = todos(:todo_one)
    @item = @todo.items.build(name: "time")
  end
  
  test "should be valid" do
    assert @item.valid?
  end
  
  test "name must be present" do
    @item.name = ""
    assert_not @item.valid?
  end
  
end
