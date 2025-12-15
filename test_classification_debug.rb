require_relative 'lib/task_classifier'
require 'ostruct'

task = OpenStruct.new(name: "ycw25", notes: "some notes")
comment = "Can you try again to update tthese market maps?"

classification = TaskClassifier.classify(task, comment)
puts "Classification: #{classification}"
