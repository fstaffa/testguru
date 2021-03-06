class CreateAnswers < ActiveRecord::Migration
  def self.up
    create_table :answers do |t|
      t.string :code
      t.text :value
      t.boolean :correct
      t.string :question_code
      t.integer :question_id
      t.string :choice

      t.timestamps
    end
  end

  def self.down
    drop_table :answers
  end
end
