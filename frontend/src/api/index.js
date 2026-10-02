import axios from 'axios'

const http = axios.create({
  baseURL: '/api',
  timeout: 20000,
  headers: { 'Content-Type': 'application/json' }
})

// 统一解包：成功直接拿 ApiResponse，失败抛出后端给的中文提示
http.interceptors.response.use(
  (response) => response.data,
  (error) => {
    const message = error.response?.data?.message || error.message || '请求失败'
    return Promise.reject(new Error(message))
  }
)

/** 日期时间 -> yyyy-MM-ddTHH:mm:ss（后端 LocalDateTime 可直接接收） */
export function fmtDateTime(value) {
  if (!value) return ''
  const d = value instanceof Date ? value : new Date(value)
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(
    d.getMinutes()
  )}:${pad(d.getSeconds())}`
}

/** 只取 HH:mm，用于发车单时间轴 */
export function fmtTime(value) {
  if (!value) return '--:--'
  const d = value instanceof Date ? value : new Date(value)
  const pad = (n) => String(n).padStart(2, '0')
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`
}

export function fmtDate(value) {
  if (!value) return ''
  const d = value instanceof Date ? value : new Date(value)
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export const api = {
  // 搅拌楼与主机
  plants: () => http.get('/plants'),
  mixers: () => http.get('/mixers'),
  mixerLoad: () => http.get('/mixers/load'),
  updateMixerPlan: (id, volume) => http.put(`/mixers/${id}/plan`, null, { params: { dailyPlanVolume: volume } }),
  updateMixerStatus: (id, status) => http.put(`/mixers/${id}/status`, null, { params: { status } }),
  faultPreview: (data) => http.post('/fault-shutdown/preview', data),
  faultConfirm: (data) => http.post('/fault-shutdown/confirm', data),

  // 生产任务单（聚合根）
  orders: (params) => http.get('/orders', { params }),
  orderDetail: (id) => http.get(`/orders/${id}`),
  createOrder: (data) => http.post('/orders', data),
  updateOrder: (id, data) => http.put(`/orders/${id}`, data),
  updateItems: (id, items) => http.put(`/orders/${id}/items`, items),
  startOrder: (id) => http.post(`/orders/${id}/start`),
  finishOrder: (id) => http.post(`/orders/${id}/finish`),
  deleteOrder: (id) => http.delete(`/orders/${id}`),

  // 罐车与发车
  trucks: () => http.get('/trucks'),
  addTruck: (data) => http.post('/trucks', data),
  updateTruck: (id, data) => http.put(`/trucks/${id}`, data),
  reorderTrucks: (ids) => http.put('/trucks/reorder', ids),
  truckReady: (id) => http.post(`/trucks/${id}/ready`),
  tickets: (orderId) => http.get('/dispatch', { params: orderId ? { orderId } : {} }),
  dispatch: (data) => http.post('/dispatch', data),
  advance: (id, action, signVolume) =>
    http.post(`/dispatch/${id}/advance`, null, { params: signVolume ? { action, signVolume } : { action } }),

  // 筒仓与补料
  silos: () => http.get('/silos'),
  lowSilos: () => http.get('/silos/low'),
  replenishes: () => http.get('/replenish'),
  applyReplenish: (data) => http.post('/replenish', data),
  approveReplenish: (id, decidedBy) => http.post(`/replenish/${id}/approve`, null, { params: { decidedBy } }),
  rejectReplenish: (id, decidedBy, remark) =>
    http.post(`/replenish/${id}/reject`, null, { params: { decidedBy, remark } }),

  // 试块质检（判定由服务端统一计算，前端只提交三块原始读数）
  qualitySamples: (params) => http.get('/quality/samples', { params }),
  registerSample: (data) => http.post('/quality/samples', data),
  sampleDetail: (id) => http.get(`/quality/samples/${id}`),
  qualityPending: () => http.get('/quality/pending'),
  submitItemResult: (id, data) => http.post(`/quality/items/${id}/result`, data),
  submitRecheckResult: (id, data) => http.post(`/quality/rechecks/${id}/result`, data),
  orderQualityChain: (orderId) => http.get(`/quality/orders/${orderId}/chain`),

  // 统计
  statGrade: () => http.get('/stats/grade'),
  statSite: () => http.get('/stats/site'),
  statDaily: (date) => http.get('/stats/daily', { params: date ? { date } : {} }),
  dashboard: () => http.get('/stats/dashboard')
}

export default api
