require 'monitor'

module Hamster

  class << self

    def list(*items)
      items.reverse.reduce(EmptyList) { |list, item| list.cons(item) }
    end

    def stream(&block)
      return EmptyList unless block_given?
      Stream.new(yield) { stream(&block) }
    end

    def interval(from, to)
      return EmptyList if from > to
      Stream.new(from) { interval(from.succ, to) }
    end
    alias_method :range, :interval

    def repeat(item)
      Stream.new(item) { repeat(item) }
    end

    def replicate(number, item)
      repeat(item).take(number)
    end

    def iterate(item, &block)
      Stream.new(item) { iterate(yield(item), &block) }
    end

  end

  module List

    Undefined = Object.new

    def empty?
      false
    end
    alias_method :null?, :empty?

    def size
      reduce(0) { |memo, item| memo.succ }
    end
    alias_method :length, :size

    def cons(item)
      Sequence.new(item, self)
    end
    alias_method :>>, :cons

    def each
      return self unless block_given?
      list = self
      while !list.empty?
        yield(list.head)
        list = list.tail
      end
    end

    def map(&block)
      return self unless block_given?
      Stream.new(yield(head)) { tail.map(&block) }
    end
    alias_method :collect, :map

    def reduce(memo = Undefined, &block)
      return tail.reduce(head, &block) if memo.equal?(Undefined)
      return memo unless block_given?
      each { |item| memo = yield(memo, item)  }
      memo
    end
    alias_method :inject, :reduce
    alias_method :fold, :reduce

    def filter(&block)
      return self unless block_given?
      list = self
      while !yield(list.head)
        list = list.tail
        return list if list.empty?
      end
      Stream.new(list.head) { list.tail.filter(&block) }
    end
    alias_method :select, :filter
    alias_method :find_all, :filter

    def reject(&block)
      return self unless block_given?
      filter { |item| !yield(item) }
    end
    alias_method :delete_if, :reject

    def take_while(&block)
      return self unless block_given?
      if yield(head)
        Stream.new(head) { tail.take_while(&block) }
      else
        EmptyList
      end
    end

    def drop_while
      return self unless block_given?
      list = self
      while !list.empty? && yield(list.head)
        list = list.tail
      end
      list
    end

    def take(number)
      return EmptyList unless number > 0
      Stream.new(head) { tail.take(number - 1) }
    end

    def drop(number)
      list = self
      while !list.empty? && number > 0
        number -= 1
        list = list.tail
      end
      list
    end

    def include?(object)
      each { |item| return true if object == item }
      false
    end
    alias_method :member?, :include?
    alias_method :contains?, :include?
    alias_method :elem?, :include?

    def any?
      return any? { |item| item } unless block_given?
      each { |item| return true if yield(item) }
      false
    end
    alias_method :exist?, :any?
    alias_method :exists?, :any?

    def all?
      return all? { |item| item } unless block_given?
      each { |item| return false unless yield(item) }
      true
    end

    def none?
      return none? { |item| item } unless block_given?
      each { |item| return false if yield(item) }
      true
    end

    def one?(&block)
      return one? { |item| item } unless block_given?
      list = self
      while !list.empty?
        return list.tail.none?(&block) if yield(list.head)
        list = list.tail
      end
      false
    end

    def find
      return nil unless block_given?
      each { |item| return item if yield(item) }
    end
    alias_method :detect, :find

    def partition(&block)
      return self unless block_given?
      Stream.new(filter(&block)) { Sequence.new(reject(&block)) }
    end

    def append(other)
      Stream.new(head) { tail.append(other) }
    end
    alias_method :concat, :append
    alias_method :cat, :append
    alias_method :+, :append

    def reverse
      reduce(EmptyList) { |list, item| list.cons(item) }
    end

    def minimum(&block)
      return minimum { |minimum, item| item <=> minimum } unless block_given?
      reduce { |minimum, item| yield(minimum, item) < 0 ? item : minimum }
    end
    alias_method :min, :minimum

    def maximum(&block)
      return maximum { |maximum, item| item <=> maximum } unless block_given?
      reduce { |maximum, item| yield(maximum, item) > 0 ? item : maximum }
    end
    alias_method :max, :maximum

    def grep(pattern, &block)
      filter { |item| pattern === item }.map(&block)
    end

    def zip(other)
      Stream.new(Sequence.new(other.head).cons(head)) { tail.zip(other.tail) }
    end

    def cycle
      Stream.new(head) { tail.append(self.cycle) }
    end

    def split_at(number)
      Sequence.new(drop(number)).cons(take(number))
    end

    def span(&block)
      return Sequence.new(EmptyList).cons(self) unless block_given?
      Stream.new(take_while(&block)) { Sequence.new(drop_while(&block)) }
    end

    def break(&block)
      return Sequence.new(EmptyList).cons(self) unless block_given?
      span { |item| !yield(item) }
    end

    def count(&block)
      return length unless block_given?
      count = 0
      each { |item| count += 1 if yield(item) }
      count
    end

    def clear
      EmptyList
    end

    def sort(&block)
      Hamster.list(*to_a.sort(&block))
    end

    def sort_by(&block)
      return sort unless block_given?
      Hamster.list(*to_a.sort_by(&block))
    end

    def join(sep = "")
      sep = sep.to_s
      tail.reduce(head.to_s) { |string, item| string << sep << item.to_s }
    end

    def eql?(other)
      return false unless other.is_a?(List)

      list = self
      while !list.empty? && !other.empty?
        return true if other.equal?(list)
        return false unless other.is_a?(List)
        return false unless other.head.eql?(list.head)
        list = list.tail
        other = other.tail
      end
      other.equal?(list)
    end
    alias_method :==, :eql?

    def dup
      self
    end
    alias_method :clone, :dup

    def to_a
      reduce([]) { |a, item| a << item }
    end
    alias_method :to_ary, :to_a
    alias_method :entries, :to_a

    def to_list
      self
    end

    def inspect
      to_a.inspect
    end

    private

    def method_missing(name, *args, &block)
      if name.to_s =~ /^c([ad]+)r$/
        accessor($1)
      else
        super
      end
    end

    # Perform compositions of <tt>car</tt> and <tt>cdr</tt> operations. Their names consist of a 'c', followed by at
    # least one 'a' or 'd', and finally an 'r'. The series of 'a's and 'd's in each function's name is chosen to
    # identify the series of car and cdr operations that is performed by the function. The order in which the 'a's and
    # 'd's appear is the inverse of the order in which the corresponding operations are performed.
    def accessor(sequence)
      sequence.split(//).reverse!.reduce(self) do |memo, char|
        case char
        when "a" then memo.head
        when "d" then memo.tail
        end
      end
    end

  end

  class Sequence

    include List

    attr_reader :head, :tail
    alias_method :first, :head

    def initialize(head, tail = EmptyList)
      @head = head
      @tail = tail
    end

  end

  class Stream

    include List

    attr_reader :head
    alias_method :first, :head

    def initialize(head, &tail)
      @head = head
      @tail = tail
      @mutex = Mutex.new
    end

    def tail
      @mutex.synchronize do
        unless defined?(@value)
          @value = @tail.call
        end
      end
      @value
    end

  end

  module EmptyList

    class << self

      include List

      def head
        nil
      end
      alias_method :first, :head

      def tail
        self
      end

      def empty?
        true
      end
      alias_method :null?, :empty?

      def map
        self
      end
      alias_method :collect, :map

      def filter
        self
      end
      alias_method :select, :filter
      alias_method :find_all, :filter

      def reject
        self
      end
      alias_method :delete_if, :reject

      def take_while
        self
      end

      def take(number)
        self
      end

      def append(other)
        other
      end
      alias_method :concat, :append
      alias_method :cat, :append
      alias_method :+, :append

      def zip(other)
        return super unless other.empty?
        self
      end

      def cycle
        self
      end

    end

  end

end
