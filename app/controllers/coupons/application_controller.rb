class Coupons::ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  include Coupons::Models
  helper Coupons::ApplicationHelper

  include PageMeta::Helpers
  helper_method :page_meta

  before_action :authorize

    def admin_required
    if !current_user.admin?
      redirect_to "/",alert: "你不是管理员"
    end
  end
  
  private

  def authorize
    Coupons.configuration.authorizer.call(self)
  end
end
