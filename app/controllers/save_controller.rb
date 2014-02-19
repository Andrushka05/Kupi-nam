class SaveController < ApplicationController
  def save_xls
    @save=Save.new
    path=@save.xls(params[:id])
  end

  def save_xlsx

  end
  def save_csv

  end
  def save_xml

  end
end
