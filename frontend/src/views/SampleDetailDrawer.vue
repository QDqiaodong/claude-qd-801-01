<template>
  <el-drawer
    :model-value="modelValue"
    :title="detail ? `试块组 ${detail.sampleNo} · ${detail.statusName}` : '试块详情'"
    size="640px"
    @update:model-value="$emit('update:modelValue', $event)"
    @open="load"
  >
    <div v-if="detail" class="sd-wrap">
      <!-- 留样快照 -->
      <div class="sd-block">
        <div class="sd-title">留样信息（登记时快照）</div>
        <div class="sd-grid">
          <div><span class="cp-muted">试块编号</span>{{ detail.sampleNo }}</div>
          <div><span class="cp-muted">组编号</span>{{ detail.groupNo }}</div>
          <div><span class="cp-muted">工程名称</span>{{ detail.projectName }}</div>
          <div>
            <span class="cp-muted">强度等级</span>
            <span class="cp-badge" :style="{ background: gradeColor(detail.strengthGrade) }">{{ detail.strengthGrade }}</span>
          </div>
          <div><span class="cp-muted">养护方式</span>{{ detail.curingMethodName }}</div>
          <div><span class="cp-muted">取样时间</span>{{ fmtTime(detail.sampleTime) }}</div>
          <div><span class="cp-muted">登记质检员</span>{{ detail.inspector }}</div>
          <div><span class="cp-muted">登记时间</span>{{ fmtTime(detail.createdAt) }}</div>
          <div><span class="cp-muted">生产任务单</span>{{ detail.orderNo }}</div>
          <div><span class="cp-muted">关联发车单</span>{{ detail.ticketNo }}</div>
        </div>
        <div class="sd-mix">
          <span class="cp-muted">配合比快照</span>
          <span v-for="m in mixList" :key="m.material" class="sd-mix-chip">{{ m.material }} {{ m.dosage }}</span>
        </div>
      </div>

      <!-- 龄期检测项 -->
      <div v-for="item in detail.items" :key="item.id" class="sd-block">
        <div class="sd-title">
          {{ item.ageDays }} 天龄期检测
          <span class="cp-tag" :class="displayClass(item.displayStatus)">{{ item.displayStatusName }}</span>
          <span class="cp-muted sd-due">应检日期 {{ item.dueDate }}</span>
        </div>

        <!-- 已检：原始读数不可覆盖 -->
        <template v-if="item.displayStatus === 'DONE'">
          <div class="sd-readings">
            <span v-for="(v, i) in [item.strength1, item.strength2, item.strength3]" :key="i" class="sd-chip">
              第{{ ['一', '二', '三'][i] }}块 <b>{{ v }}</b> MPa
            </span>
          </div>
          <div class="sd-verdict">
            平均值 <b>{{ item.avgStrength }}</b> MPa · 最小值 <b>{{ item.minStrength }}</b> MPa
            <span class="cp-tag" :class="verdictClass(item.verdict)" style="margin-left: 8px">{{ item.verdictName }}</span>
          </div>
          <div class="cp-muted sd-meta">
            {{ item.ageDays === 28 ? `验收门槛：平均值 ≥ ${item.avgThreshold} 且最小值 ≥ ${item.minThreshold} MPa`
                                   : `趋势参考：平均值 ≥ ${item.trendReference} MPa（只作趋势，不影响终判）` }}
          </div>
          <div class="cp-muted sd-meta">检测人 {{ item.testedBy }} · {{ fmtTime(item.testedAt) }}</div>
        </template>

        <!-- 待检 / 逾期：录入三块抗压强度 -->
        <template v-else-if="item.displayStatus === 'DUE' || item.displayStatus === 'OVERDUE'">
          <div v-if="locked" class="cp-muted sd-meta">试块组已锁定为不合格，不能再录入检测结果</div>
          <template v-else>
            <div class="sd-form">
              <el-input-number
                v-for="i in 3"
                :key="i"
                v-model="forms['item-' + item.id]['s' + i]"
                :min="0" :max="150" :step="0.5" :precision="2" size="small"
                :placeholder="`第${i}块 MPa`"
                controls-position="right"
                style="width: 118px"
              />
              <el-input
                v-model="forms['item-' + item.id].by"
                size="small"
                placeholder="检测人"
                maxlength="32"
                style="width: 110px"
              />
              <el-button size="small" type="primary" :loading="saving" @click="submitItem(item)">提交结果</el-button>
            </div>
            <div class="cp-muted sd-meta">
              {{ item.ageDays === 28 ? `服务端判定：平均值 ≥ ${item.avgThreshold} 且最小值 ≥ ${item.minThreshold} MPa 判合格，否则生成复检任务`
                                     : `7 天结果只作趋势参考（≥ ${item.trendReference} MPa），不改变最终质量状态` }}
            </div>
          </template>
        </template>

        <!-- 未到期 -->
        <div v-else class="cp-muted sd-meta">未到 {{ item.ageDays }} 天目标龄期，不得录入正式结果</div>
      </div>

      <!-- 复检任务 -->
      <div v-if="detail.recheck" class="sd-block sd-recheck">
        <div class="sd-title">
          复检任务 {{ detail.recheck.recheckNo }}
          <span class="cp-tag" :class="detail.recheck.status === 'DONE' ? verdictClass(detail.recheck.verdict) : 'warn'">
            {{ detail.recheck.statusName }}
          </span>
        </div>
        <div class="cp-muted sd-meta">
          引用原 28 天检测项 #{{ detail.recheck.originItemId }} · 生成于 {{ fmtTime(detail.recheck.createdAt) }}；原始读数保留在上方检测项中，不可覆盖
        </div>

        <template v-if="detail.recheck.status === 'DONE'">
          <div class="sd-readings">
            <span v-for="(v, i) in [detail.recheck.strength1, detail.recheck.strength2, detail.recheck.strength3]" :key="i" class="sd-chip">
              第{{ ['一', '二', '三'][i] }}块 <b>{{ v }}</b> MPa
            </span>
          </div>
          <div class="sd-verdict">
            平均值 <b>{{ detail.recheck.avgStrength }}</b> MPa · 最小值 <b>{{ detail.recheck.minStrength }}</b> MPa
            <span class="cp-tag" :class="verdictClass(detail.recheck.verdict)" style="margin-left: 8px">{{ detail.recheck.verdictName }}</span>
          </div>
          <div class="cp-muted sd-meta">复检人 {{ detail.recheck.testedBy }} · {{ fmtTime(detail.recheck.testedAt) }}</div>
        </template>

        <template v-else>
          <div class="sd-form">
            <el-input-number
              v-for="i in 3"
              :key="i"
              v-model="forms['recheck-' + detail.recheck.id]['s' + i]"
              :min="0" :max="150" :step="0.5" :precision="2" size="small"
              :placeholder="`第${i}块 MPa`"
              controls-position="right"
              style="width: 118px"
            />
            <el-input
              v-model="forms['recheck-' + detail.recheck.id].by"
              size="small"
              placeholder="复检人"
              maxlength="32"
              style="width: 110px"
            />
            <el-button size="small" type="primary" :loading="saving" @click="submitRecheck">提交复检</el-button>
          </div>
          <div class="cp-muted sd-meta">
            复检合格试块组才转「已合格」；复检仍失败锁定为「不合格」。判定门槛：平均值 ≥ {{ detail.recheck.avgThreshold }} 且最小值 ≥ {{ detail.recheck.minThreshold }} MPa
          </div>
        </template>
      </div>
    </div>
    <div v-else class="cp-empty">加载中…</div>
  </el-drawer>
</template>

<script setup>
import { computed, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { api, fmtTime } from '../api'

const props = defineProps({
  modelValue: Boolean,
  sampleId: Number
})
const emit = defineEmits(['update:modelValue', 'changed'])

const detail = ref(null)
const saving = ref(false)
const forms = reactive({})

const locked = computed(() => detail.value?.status === 'UNQUALIFIED')

const mixList = computed(() => {
  try {
    return JSON.parse(detail.value?.mixSnapshot || '[]')
  } catch (e) {
    return []
  }
})

async function load() {
  if (!props.sampleId) return
  detail.value = null
  try {
    const res = await api.sampleDetail(props.sampleId)
    detail.value = res.data
    for (const item of res.data.items || []) {
      forms['item-' + item.id] = forms['item-' + item.id] || { s1: null, s2: null, s3: null, by: '' }
    }
    if (res.data.recheck) {
      const key = 'recheck-' + res.data.recheck.id
      forms[key] = forms[key] || { s1: null, s2: null, s3: null, by: '' }
    }
  } catch (e) {
    ElMessage.error(e.message)
  }
}

function payloadOf(form) {
  return { strength1: form.s1, strength2: form.s2, strength3: form.s3, testedBy: form.by }
}

function validForm(form) {
  if (!form.s1 || !form.s2 || !form.s3) {
    ElMessage.warning('请录入三块试块的抗压强度')
    return false
  }
  if (!form.by || !form.by.trim()) {
    ElMessage.warning('请填写检测人')
    return false
  }
  return true
}

async function submitItem(item) {
  const form = forms['item-' + item.id]
  if (!validForm(form)) return
  saving.value = true
  try {
    await api.submitItemResult(item.id, payloadOf(form))
    ElMessage.success('检测结果已录入，判定由服务端完成')
    await afterChange()
  } catch (e) {
    // 并发冲突 / 状态已变化：刷新详情，让后到者看到最新状态
    ElMessage.error(e.message)
    await load()
  } finally {
    saving.value = false
  }
}

async function submitRecheck() {
  const form = forms['recheck-' + detail.value.recheck.id]
  if (!validForm(form)) return
  saving.value = true
  try {
    await api.submitRecheckResult(detail.value.recheck.id, payloadOf(form))
    ElMessage.success('复检结果已录入')
    await afterChange()
  } catch (e) {
    ElMessage.error(e.message)
    await load()
  } finally {
    saving.value = false
  }
}

async function afterChange() {
  await load()
  emit('changed')
}

function gradeColor(grade) {
  return { C25: '#5b8fa8', C30: '#2f4f4f', C35: '#8a6f4f', C40: '#8c4a3a' }[grade] || '#2f4f4f'
}

function displayClass(status) {
  return { NOT_DUE: '', DUE: 'warn', OVERDUE: 'danger', DONE: 'ok' }[status] || ''
}

function verdictClass(verdict) {
  return verdict === 'PASS' ? 'ok' : verdict === 'FAIL' ? 'danger' : ''
}
</script>

<style scoped>
.sd-wrap {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.sd-block {
  border: 1px solid var(--cp-border);
  border-radius: 8px;
  padding: 12px 14px;
}

.sd-recheck {
  border-color: #e5cdae;
  background: #fffdf9;
}

.sd-title {
  font-size: 13px;
  font-weight: 700;
  color: var(--cp-primary);
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 10px;
}

.sd-due {
  font-size: 11px;
  font-weight: 400;
  margin-left: auto;
}

.sd-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 6px 18px;
  font-size: 12px;
}

.sd-grid .cp-muted {
  display: inline-block;
  width: 66px;
}

.sd-mix {
  margin-top: 10px;
  font-size: 11px;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
}

.sd-mix-chip {
  padding: 1px 8px;
  border-radius: 10px;
  background: #f4f8f7;
  border: 1px solid var(--cp-border);
  color: #46605e;
}

.sd-readings {
  display: flex;
  gap: 8px;
  margin-bottom: 8px;
}

.sd-chip {
  padding: 3px 10px;
  border-radius: 6px;
  background: #f4f8f7;
  border: 1px solid var(--cp-border);
  font-size: 12px;
}

.sd-verdict {
  font-size: 12px;
  display: flex;
  align-items: center;
}

.sd-verdict b {
  color: var(--cp-primary);
}

.sd-meta {
  font-size: 11px;
  margin-top: 6px;
}

.sd-form {
  display: flex;
  gap: 8px;
  align-items: center;
  flex-wrap: wrap;
}
</style>
