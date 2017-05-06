require 'test_helper'

class TodoTest < ActiveSupport::TestCase
  def setup
    @todo = Todo.new(title: "Study React", created_by: "Joshua")
  end
  
  test "should be valid" do
    assert @todo.valid?
  end
  
  test "title should be present" do
    @todo.title = ""
    assert_not @todo.valid?
  end
  
  test "created_by should be present" do
    @todo.created_by = ""
    assert_not @todo.valid?
  end
  
end
