class AddColumnShowAttachmentAtInStreamsTable < ActiveRecord::Migration[5.0]
  def change
    add_column :streams, :show_attachment_at, :integer
  end
end
