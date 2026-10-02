<template>
  <div>
    <!-- 待检清单 -->
    <div class="cp-panel">
      <div class="cp-panel-head">
        <div class="cp-panel-title">待检清单</div>
        <div class="cp-panel-sub">已到龄期的检测项与待复检任务；超过宽限期仍未检的标红为逾期</div>
        <div style="margin-left: auto">
          <el-button size="small" @click="load">刷新</el-button>
        </div>
      </div>
      <div class="cp-panel-body">
        <div v-if="!pending.length" class="cp-empty">暂无待检项，所有到龄期试块都已检测</div>
        <div v-else class="qv-pending">
          <div v-for="p in pending" :key="`${p.kind}-${p.refId}`" class="qv-pending-row">
            <span class="cp-tag" :class="p.kind === 'RECHECK' ? 'danger' : 'run'">{{ p.kindName }}</span>
            <b>{{ p.sampleNo }}</b>
            <span class="cp-badge" :style="{ background: gradeColor(p.strengthGrade) }">{{ p.strengthGrade }}</span>
            <span class="cp-muted qv-proj">{{ p.projectName }}</span>
            <span class="cp-muted">应检 {{ p.dueDate }}</span>
            <span class="cp-tag" :class="displayClass(p.displayStatus)" style="margin-left: auto">
              {{ p.displayStatusName }}
            </span>
            <el-button size="small" type="primary" @click="openDetail(p.sampleId)">去录入</el-button>
          </div>
        </div>
      </div>
    </div>

    <!-- 试块组台账 -->
    <div class="cp-panel" style="margin-top: 14px">
      <div class="cp-panel-head">
        <div class="cp-panel-title">试块组台账</div>
        <div class="cp-panel-sub">留样 → 7/28 天龄期检测 → 复检追溯；判定阈值由服务端统一计算</div>
        <div style="margin-left: auto; display: flex; gap: 8px">
          <el-select v-model="filter.status" size="small" clearable placeholder="质量状态" style="width: 116px" @change="loadSamples">
            <el-option label="检测中" value="TESTING" />
            <el-option label="已合格" value="QUALIFIED" />
            <el-option label="待复检" value="RECHECKING" />
            <el-option label="不合格" value="UNQUALIFIED" />
          </el-select>
          <el-select v-model="filter.grade" size="small" clearable placeholder="强度等级" style="width: 104px" @change="loadSamples">
            <el-option v-for="g in grades" :key="g" :label="g" :value="g" />
          </el-select>
          <el-input
            v-model="filter.keyword"
            size="small"
            clearable
            placeholder="试块编号 / 工程 / 任务单号"
            style="width: 180px"
            @change="loadSamples"
            @clear="loadSamples"
          />
          <el-button size="small" type="primary" @click="openRegister">登记试块组</el-button>
        </div>
      </div>
      <div class="cp-panel-body">
        <div v-if="!samples.length" class="cp-empty">暂无试块组，点右上角「登记试块组」留样</div>
        <table v-else class="qv-table">
          <thead>
            <tr>
              <th>试块编号</th><th>工程（快照）</th><th>等级</th><th>养护方式</th><th>取样时间</th>
              <th>7 天</th><th>28 天</th><th>复检</th><th>质量状态</th><th></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="s in samples" :key="s.id">
              <td><b>{{ s.sampleNo }}</b><div class="cp-muted qv-sub">{{ s.orderNo }}</div></td>
              <td>{{ s.projectName }}</td>
              <td><span class="cp-badge" :style="{ background: gradeColor(s.strengthGrade) }">{{ s.strengthGrade }}</span></td>
              <td>{{ s.curingMethodName }}</td>
              <td class="qv-nowrap">{{ fmtTime(s.sampleTime) }}</td>
              <td><span class="cp-tag" :class="displayClass(itemOf(s, 7)?.displayStatus)">{{ itemOf(s, 7)?.displayStatusName || '—' }}</span></td>
              <td><span class="cp-tag" :class="displayClass(itemOf(s, 28)?.displayStatus)">{{ itemOf(s, 28)?.displayStatusName || '—' }}</span></td>
              <td>
                <span v-if="s.recheck" class="cp-tag" :class="s.recheck.status === 'DONE' ? verdictClass(s.recheck.verdict) : 'warn'">
                  {{ s.recheck.statusName }}
                </span>
                <span v-else class="cp-muted">—</span>
              </td>
              <td><span class="cp-tag" :class="sampleClass(s.status)">{{ s.statusName }}</span></td>
              <td><el-button size="small" @click="openDetail(s.id)">详情</el-button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 登记试块组 -->
    <el-dialog v-model="regDialog" title="登记试块组（留样）" width="560px">
      <el-form label-width="96px" size="small">
        <el-form-item label="生产任务单">
          <el-select v-model="reg.orderId" style="width: 100%" placeholder="选择任务单" @change="onOrderChange">
            <el-option
              v-for="o in ticketOrders"
              :key="o.id"
              :label="`${o.orderNo} · ${o.projectName}（${o.strengthGrade}）`"
              :value="o.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="关联发车单">
          <el-select v-model="reg.ticketId" style="width: 100%" placeholder="选择同一任务下已装车的发车单" :disabled="!reg.orderId">
            <el-option
              v-for="t in orderTickets"
              :key="t.id"
              :label="`${t.ticketNo} · ${t.plateNo} · 装车 ${fmtTime(t.loadTime)}`"
              :value="t.id"
            />
          </el-select>
          <div class="cp-muted qv-hint">试块必须取自同一任务下至少一张已装车的发车单</div>
        </el-form-item>
        <el-form-item label="试块编号">
          <el-input v-model="reg.sampleNo" placeholder="如 SK-2609-01（唯一，重复登记会被拦下）" maxlength="32" />
        </el-form-item>
        <el-form-item label="取样时间">
          <el-date-picker
            v-model="reg.sampleTime"
            type="datetime"
            style="width: 100%"
            value-format="YYYY-MM-DDTHH:mm:ss"
            placeholder="实际取样时间"
          />
        </el-form-item>
        <el-form-item label="养护方式">
          <el-radio-group v-model="reg.curingMethod">
            <el-radio value="STANDARD">标准养护</el-radio>
            <el-radio value="SAME_CONDITION">同条件养护</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="质检员">
          <el-input v-model="reg.inspector" placeholder="登记质检员姓名" maxlength="32" />
        </el-form-item>
      </el-form>
      <div class="qv-snapshot" v-if="curOrder">
        登记即快照：工程「{{ curOrder.projectName }}」· 强度等级 {{ curOrder.strengthGrade }} · 当前配合比；
        保存后按取样时间自动生成 7 天 / 28 天检测项
      </div>
      <template #footer>
        <el-button size="small" @click="regDialog = false">取消</el-button>
        <el-button size="small" type="primary" :loading="regSaving" @click="doRegister">保存登记</el-button>
      </template>
    </el-dialog>

    <!-- 试块详情抽屉 -->
    <SampleDetailDrawer v-model="detailVisible" :sample-id="detailId" @changed="load" />
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { api, fmtTime } from '../api'
import SampleDetailDrawer from './SampleDetailDrawer.vue'

const grades = ['C25', 'C30', 'C35', 'C40']
const pending = ref([])
const samples = ref([])
const orders = ref([])
const tickets = ref([])
const filter = reactive({ status: '', grade: '', keyword: '' })

const regDialog = ref(false)
const regSaving = ref(false)
const reg = reactive({ orderId: null, ticketId: null, sampleNo: '', sampleTime: '', curingMethod: 'STANDARD', inspector: '' })

const detailVisible = ref(false)
const detailId = ref(null)

/** 有发车记录的任务单才能留样 */
const ticketOrders = computed(() => orders.value.filter((o) => tickets.value.some((t) => t.orderId === o.id)))
const orderTickets = computed(() => tickets.value.filter((t) => t.orderId === reg.orderId && t.loadTime))
const curOrder = computed(() => orders.value.find((o) => o.id === reg.orderId) || null)

async function load() {
  await Promise.all([loadPending(), loadSamples()])
}

async function loadPending() {
  try {
    const res = await api.qualityPending()
    pending.value = res.data || []
  } catch (e) {
    ElMessage.error(e.message)
  }
}

async function loadSamples() {
  try {
    const params = {}
    if (filter.status) params.status = filter.status
    if (filter.grade) params.grade = filter.grade
    if (filter.keyword) params.keyword = filter.keyword
    const res = await api.qualitySamples(params)
    samples.value = res.data || []
  } catch (e) {
    ElMessage.error(e.message)
  }
}

async function openRegister() {
  reg.orderId = null
  reg.ticketId = null
  reg.sampleNo = ''
  reg.sampleTime = ''
  reg.curingMethod = 'STANDARD'
  reg.inspector = ''
  try {
    const [od, tk] = await Promise.all([api.orders(), api.tickets()])
    orders.value = od.data || []
    tickets.value = tk.data || []
    regDialog.value = true
  } catch (e) {
    ElMessage.error(e.message)
  }
}

function onOrderChange() {
  reg.ticketId = orderTickets.value[0]?.id ?? null
}

async function doRegister() {
  if (!reg.orderId) return ElMessage.warning('请选择生产任务单')
  if (!reg.ticketId) return ElMessage.warning('请选择关联发车单')
  if (!reg.sampleNo.trim()) return ElMessage.warning('请填写试块编号')
  if (!reg.sampleTime) return ElMessage.warning('请选择取样时间')
  if (!reg.inspector.trim()) return ElMessage.warning('请填写质检员')
  regSaving.value = true
  try {
    await api.registerSample({
      orderId: reg.orderId,
      ticketId: reg.ticketId,
      sampleNo: reg.sampleNo.trim(),
      sampleTime: reg.sampleTime,
      curingMethod: reg.curingMethod,
      inspector: reg.inspector.trim()
    })
    ElMessage.success('试块组已登记，7 天 / 28 天检测项已生成')
    regDialog.value = false
    await load()
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    regSaving.value = false
  }
}

function openDetail(id) {
  detailId.value = id
  detailVisible.value = true
}

function itemOf(sample, age) {
  return (sample.items || []).find((i) => i.ageDays === age)
}

function gradeColor(grade) {
  return { C25: '#5b8fa8', C30: '#2f4f4f', C35: '#8a6f4f', C40: '#8c4a3a' }[grade] || '#2f4f4f'
}

function displayClass(status) {
  return { NOT_DUE: '', DUE: 'warn', OVERDUE: 'danger', DONE: 'ok' }[status] || ''
}

function sampleClass(status) {
  return { TESTING: 'run', QUALIFIED: 'ok', RECHECKING: 'warn', UNQUALIFIED: 'danger' }[status] || ''
}

function verdictClass(verdict) {
  return verdict === 'PASS' ? 'ok' : verdict === 'FAIL' ? 'danger' : ''
}

onMounted(load)
</script>

<style scoped>
.qv-pending {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.qv-pending-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border: 1px solid var(--cp-border);
  border-radius: 6px;
  font-size: 12px;
}

.qv-proj {
  max-width: 220px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.qv-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

.qv-table th {
  text-align: left;
  color: var(--cp-muted);
  font-weight: 600;
  padding: 6px 8px;
  border-bottom: 1px solid var(--cp-border);
  white-space: nowrap;
}

.qv-table td {
  padding: 8px;
  border-bottom: 1px solid #edf1f0;
  vertical-align: middle;
}

.qv-sub {
  font-size: 11px;
}

.qv-nowrap {
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}

.qv-hint {
  font-size: 11px;
  margin-top: 4px;
}

.qv-snapshot {
  margin-top: 4px;
  padding: 8px 12px;
  background: #f4f8f7;
  border: 1px solid var(--cp-border);
  border-radius: 6px;
  font-size: 11px;
  color: var(--cp-muted);
  line-height: 1.7;
}
</style>
