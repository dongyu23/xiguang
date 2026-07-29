package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"xiguang/backend/internal/auth"
	"xiguang/backend/internal/island/domain"
	"xiguang/backend/internal/island/service"
	"xiguang/backend/internal/shared"
)

type Handler struct {
	service *service.Service
}

func New(service *service.Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.list)
	r.Post("/", h.create)
	r.Get("/{id}", h.get)
	r.Put("/{id}", h.update)
	r.Delete("/{id}", h.delete)
	r.Post("/{id}/fragments", h.addFragments)
	r.Delete("/{id}/fragments", h.removeFragments)
	r.Get("/{name}/fragments", h.fragments)
	return r
}

func (h *Handler) GroupRoutes() http.Handler {
	r := chi.NewRouter()
	r.Get("/", h.listGroups)
	r.Post("/", h.createGroup)
	r.Get("/{id}", h.getGroup)
	r.Put("/{id}", h.updateGroup)
	r.Delete("/{id}", h.deleteGroup)
	r.Post("/{id}/islands", h.addGroupIslands)
	r.Delete("/{id}/islands", h.removeGroupIslands)
	return r
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Routes().ServeHTTP(w, r)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	items, err := h.service.List(r.Context(), userID)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法读取小宇宙。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"islands": items})
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	params, ok := decodeUpsert(w, r)
	if !ok {
		return
	}
	dto, err := h.service.Create(r.Context(), userID, params)
	if errors.Is(err, service.ErrEmptyName) {
		shared.WriteError(w, http.StatusBadRequest, "island_empty", "小岛名称不能为空。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法创建小岛。")
		return
	}
	shared.WriteJSON(w, http.StatusCreated, dto)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	dto, err := h.service.Get(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "island_not_found", "没有找到这座小岛。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	params, ok := decodeUpsert(w, r)
	if !ok {
		return
	}
	dto, err := h.service.Update(r.Context(), userID, id, params)
	if errors.Is(err, service.ErrEmptyName) {
		shared.WriteError(w, http.StatusBadRequest, "island_empty", "小岛名称不能为空。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusNotFound, "island_not_found", "没有找到这座小岛。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	deleted, err := h.service.Delete(r.Context(), userID, id)
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法删除小岛。")
		return
	}
	if !deleted {
		shared.WriteError(w, http.StatusNotFound, "island_not_found", "没有找到这座小岛。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]bool{"deleted": true})
}

func (h *Handler) addFragments(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	islandID, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)

	var action domain.FragmentAction
	if err := shared.DecodeJSON(r, &action); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}

	dto, err := h.service.AddFragments(r.Context(), userID, islandID, action.FragmentIDs)
	if errors.Is(err, service.ErrNotManualIsland) {
		shared.WriteError(w, http.StatusForbidden, "island_not_manual", "自动生长的小岛不能手动添加光片。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法添加光片。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
}

func (h *Handler) removeFragments(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	islandID, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)

	var action domain.FragmentAction
	if err := shared.DecodeJSON(r, &action); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return
	}

	dto, err := h.service.RemoveFragments(r.Context(), userID, islandID, action.FragmentIDs)
	if errors.Is(err, service.ErrNotManualIsland) {
		shared.WriteError(w, http.StatusForbidden, "island_not_manual", "自动生长的小岛不能手动移除光片。")
		return
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法移除光片。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, dto)
}

func (h *Handler) fragments(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserID(r.Context())
	name := chi.URLParam(r, "name")
	var (
		items []domain.FragmentPreview
		err   error
	)
	if islandID, parseErr := strconv.ParseInt(name, 10, 64); parseErr == nil {
		items, err = h.service.FragmentsByID(r.Context(), userID, islandID, r.URL.Query().Get("limit"))
	} else {
		items, err = h.service.Fragments(r.Context(), userID, name, r.URL.Query().Get("limit"))
	}
	if err != nil {
		shared.WriteError(w, http.StatusInternalServerError, "island_failed", "暂时无法读取岛内光片。")
		return
	}
	shared.WriteJSON(w, http.StatusOK, map[string]any{"name": name, "fragments": items})
}

func decodeUpsert(w http.ResponseWriter, r *http.Request) (domain.UpsertParams, bool) {
	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := shared.DecodeJSON(r, &req); err != nil {
		shared.WriteError(w, http.StatusBadRequest, "bad_request", "请求格式不正确。")
		return domain.UpsertParams{}, false
	}
	return domain.UpsertParams{Name: req.Name, Description: req.Description}, true
}

func (h *Handler) listGroups(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	items, err := h.service.ListGroups(r.Context(), uid)
	if err != nil {
		shared.WriteError(w, 500, "island_group_failed", "暂时无法读取岛群。")
		return
	}
	shared.WriteJSON(w, 200, map[string]any{"groups": items})
}
func (h *Handler) createGroup(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	var req domain.GroupUpsertParams
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, 400, "bad_request", "请求格式不正确。")
		return
	}
	item, err := h.service.CreateGroup(r.Context(), uid, req)
	if errors.Is(err, service.ErrInvalidGroup) {
		shared.WriteError(w, 422, "invalid_island_group", "岛群需要名称和 2 到 5 座小岛。")
		return
	}
	if err != nil {
		shared.WriteError(w, 400, "island_group_failed", "岛群成员无效或不属于当前账号。")
		return
	}
	shared.WriteJSON(w, 201, item)
}
func (h *Handler) getGroup(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	item, err := h.service.GetGroup(r.Context(), uid, id)
	if err != nil {
		shared.WriteError(w, 404, "island_group_not_found", "没有找到这个岛群。")
		return
	}
	shared.WriteJSON(w, 200, item)
}
func (h *Handler) updateGroup(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	var req domain.GroupUpsertParams
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, 400, "bad_request", "请求格式不正确。")
		return
	}
	item, err := h.service.UpdateGroup(r.Context(), uid, id, req)
	if err != nil {
		shared.WriteError(w, 404, "island_group_not_found", "没有找到这个岛群。")
		return
	}
	shared.WriteJSON(w, 200, item)
}
func (h *Handler) deleteGroup(w http.ResponseWriter, r *http.Request) {
	uid, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	ok, err := h.service.DeleteGroup(r.Context(), uid, id)
	if err != nil || !ok {
		shared.WriteError(w, 404, "island_group_not_found", "没有找到这个岛群。")
		return
	}
	shared.WriteJSON(w, 200, map[string]bool{"deleted": true})
}
func (h *Handler) addGroupIslands(w http.ResponseWriter, r *http.Request) {
	h.changeGroupIslands(w, r, true)
}
func (h *Handler) removeGroupIslands(w http.ResponseWriter, r *http.Request) {
	h.changeGroupIslands(w, r, false)
}
func (h *Handler) changeGroupIslands(w http.ResponseWriter, r *http.Request, add bool) {
	uid, _ := auth.UserID(r.Context())
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	var req domain.GroupMemberAction
	if shared.DecodeJSON(r, &req) != nil {
		shared.WriteError(w, 400, "bad_request", "请求格式不正确。")
		return
	}
	var item domain.IslandGroup
	var err error
	if add {
		item, err = h.service.AddGroupIslands(r.Context(), uid, id, req.IslandIDs)
	} else {
		item, err = h.service.RemoveGroupIslands(r.Context(), uid, id, req.IslandIDs)
	}
	if err != nil {
		shared.WriteError(w, 400, "island_group_failed", "无法变更岛群成员。")
		return
	}
	shared.WriteJSON(w, 200, item)
}
