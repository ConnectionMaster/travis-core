class AddIndexOnExecutionLogsBuildId < ActiveRecord::Migration
  def change
    add_index :execution_logs, :build_id, name: 'build_id_index'
  end
end
