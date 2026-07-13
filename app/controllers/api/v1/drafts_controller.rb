module Api
  module V1
    # Backs the content brainstorm board (public/board.html). Thin wrapper over
    # ContentDraftStore. Read-only GET plus create/update/destroy for triage and
    # a promote action that writes accepted drafts into cards.yml.
    class DraftsController < BaseController
      # GET /api/v1/drafts — drafts + live core content for reference.
      def index
        render json: { drafts: ContentDraftStore.all, core: ContentDraftStore.core }
      end

      # POST /api/v1/drafts
      def create
        render json: ContentDraftStore.create(draft_params), status: :created
      end

      # PATCH /api/v1/drafts/:id — status moves (drag) and inline field edits.
      def update
        render json: ContentDraftStore.update(params[:id], draft_params)
      end

      # DELETE /api/v1/drafts/:id
      def destroy
        ContentDraftStore.destroy(params[:id])
        head :no_content
      end

      # POST /api/v1/drafts/promote — append accepted drafts to cards.yml.
      def promote
        promoted = ContentDraftStore.promote!
        render json: { promoted: promoted, count: promoted.size }
      end

      private

      def draft_params
        params.permit(
          :id, :name, :category, :type_affinity, :rarity, :slot_type, :tier,
          :description, :status, :notes, :origin, :key, :upgrades_to,
          rules: {}, valid_types: [], valid_subclasses: []
        ).to_h.stringify_keys
      end
    end
  end
end
