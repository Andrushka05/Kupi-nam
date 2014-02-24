class SaveController < ApplicationController
  def save_xls
    @save=Save.new
    path=@save.xls(params[:id])
    send_file path, :type => 'application/vnd.ms-excel', :stream => false
  end

  def save_xlsx

  end
  def save_csv

  end
  def save_xml

  end
end
