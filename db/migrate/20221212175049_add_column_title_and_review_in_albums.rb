class AddColumnTitleAndReviewInAlbums < ActiveRecord::Migration[5.0]
  def change
    add_column :albums, :web_title, :string
    add_column :albums, :web_review, :string
    add_column :albums, :mobile_title, :string
    add_column :albums, :mobile_review, :string
  end
end
