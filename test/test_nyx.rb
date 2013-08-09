require 'test/unit'
require 'nyx'

class NyxTest < Test::Unit::TestCase
	def test_hello
		assert_equal "hello nyx",
		Nyx.hi()
	end
end