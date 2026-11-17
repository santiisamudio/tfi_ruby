class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.string :source_url
      t.text :welcome_text

      t.timestamps
    end
  end
end
