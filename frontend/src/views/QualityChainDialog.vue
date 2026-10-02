<template>
  <el-dialog
    :model-value="modelValue"
    :title="chain ? `检测链 · ${chain.orderNo} ${chain.projectName}` : '试块检测链'"
    width="720px"
    @update:model-value="$emit('update:modelValue', $event)"
    @open="load"
  >
    <div v-if="chain">
      <div class="qc-head">
        <span class="cp-badge" :style="{ background: gradeColor(chain.strengthGrade) }">{{ chain.strengthGrade }}</span>
        <span class="cp-tag" :class="orderClass(chain.orderStatus)">{{ chain.orderStatusName }}</span>
        <span class="cp-muted">共 {{ chain.samples.length }} 组试块留样</span>
      </div>

      <div v-if="!chain.samples.length" class="cp-empty">该任务单暂无试块留样，请到「质检」页登记</div>

      <div v-for="s in chain.samples" :key="s.id" class="qc-sample">
        <div class="qc-sample-head">
          <b>{{ s.sampleNo }}</b>
          <span class="cp-tag" :class="sampleClass(s.status)">{{ s.statusName }}</span>
          <span class="cp-muted">{{ s.curingMethodName }} · 取样 {{ fmtTime(s.sampleTime) }} · {{ s.inspector }}</span>
          <span class="cp-muted" style="margin-left: auto">发车单 {{ s.ticketNo }}</span>
        </div>

        <div class="qc-items">
          <div v-for="item in s.items" :key="item.id" class="qc-item">
            <span class="qc-age">{{ item.ageDays }} 天</span>
            <span class="cp-tag" :class="displayClass(item.displayStatus)">{{ item.displayStatusName }}</span>
            <template v-if="item.displayStatus === 'DONE'">
              <span class="qc-nums">
                {{ item.strength1 }} / {{ item.strength2 }} / {{ item.strength3 }} MPa
              </span>
              <span>均值 <b>{{ item.avgStrength }}</b> · 最小 <b>{{ item.minStrength }}</b></span>
              <span class="cp-tag" :class="verdictClass(item.verdict)">{{ item.verdictName }}</span>
              <span class="cp-muted">{{ item.testedBy }} · {{ fmtTime(item.testedAt) }}</span>
            </template>
            <span v-else class="cp-muted">应检 {{ item.dueDate }}</span>
          </div>

          <div v-if="s.recheck" class="qc-item qc-recheck">
            <span class="qc-age">复检</span>
            <span class="cp-tag" :class="s.recheck.status === 'DONE' ? verdictClass(s.recheck.verdict) : 'warn'">
              {{ s.recheck.statusName }}
            </span>
            <template v-if="s.recheck.status === 'DONE'">
              <span class="qc-nums">
                {{ s.recheck.strength1 }} / {{ s.recheck.strength2 }} / {{ s.recheck.strength3 }} MPa
              </span>
              <span>均值 <b>{{ s.recheck.avgStrength }}</b> · 最小 <b>{{ s.recheck.minStrength }}</b></span>
              <span class="cp-tag" :class="verdictClass(s.recheck.verdict)">{{ s.recheck.verdictName }}</span>
              <span class="cp-muted">{{ s.recheck.testedBy }} · {{ fmtTime(s.recheck.testedAt) }}</span>
            </template>
            <span v-else class="cp-muted">{{ s.recheck.recheckNo }} · 引用原 28 天检测项，等待复检</span>
          </div>
        </div>
      </div>
    </div>
    <div v-else class="cp-empty">加载中…</div>
  </el-dialog>
</template>

<script setup>
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { api, fmtTime } from '../api'

const props = defineProps({
  modelValue: Boolean,
  orderId: Number
})
defineEmits(['update:modelValue'])

const chain = ref(null)

async function load() {
  if (!props.orderId) return
  chain.value = null
  try {
    const res = await api.orderQualityChain(props.orderId)
    chain.value = res.data
  } catch (e) {
    ElMessage.error(e.message)
  }
}

function gradeColor(grade) {
  return { C25: '#5b8fa8', C30: '#2f4f4f', C35: '#8a6f4f', C40: '#8c4a3a' }[grade] || '#2f4f4f'
}

function orderClass(status) {
  return { PENDING: '', PRODUCING: 'run', DONE: 'ok' }[status] || ''
}

function sampleClass(status) {
  return { TESTING: 'run', QUALIFIED: 'ok', RECHECKING: 'warn', UNQUALIFIED: 'danger' }[status] || ''
}

function displayClass(status) {
  return { NOT_DUE: '', DUE: 'warn', OVERDUE: 'danger', DONE: 'ok' }[status] || ''
}

function verdictClass(verdict) {
  return verdict === 'PASS' ? 'ok' : verdict === 'FAIL' ? 'danger' : ''
}
</script>

<style scoped>
.qc-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
  font-size: 12px;
}

.qc-sample {
  border: 1px solid var(--cp-border);
  border-radius: 8px;
  padding: 10px 12px;
  margin-bottom: 10px;
}

.qc-sample-head {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  margin-bottom: 8px;
}

.qc-items {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.qc-item {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 12px;
  padding: 6px 10px;
  background: #f7faf9;
  border-radius: 6px;
}

.qc-recheck {
  background: #fdf5ea;
}

.qc-age {
  font-weight: 700;
  color: var(--cp-primary);
  min-width: 36px;
}

.qc-nums {
  font-variant-numeric: tabular-nums;
  color: #46605e;
}
</style>
