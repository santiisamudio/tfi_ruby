class ChatbotNodesController < ApplicationController
  allow_unauthenticated_access

  def show
    @node = ChatbotNode.find(params[:id])

    if @node.nil? || !@node.askable?
      head :not_found
    else
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path }
      end
    end
  end
end
