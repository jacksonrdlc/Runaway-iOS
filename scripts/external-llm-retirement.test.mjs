import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'

const trainingPlanService = fs.readFileSync(
  new URL('../Runaway iOS/Services/TrainingPlanService.swift', import.meta.url),
  'utf8',
)
const project = fs.readFileSync(
  new URL('../Runaway iOS.xcodeproj/project.pbxproj', import.meta.url),
  'utf8',
)
const contentView = fs.readFileSync(
  new URL('../Runaway iOS/Views/ContentView.swift', import.meta.url),
  'utf8',
)
const foundationModelsService = fs.readFileSync(
  new URL('../Runaway iOS/Services/FoundationModels/FoundationModelsService.swift', import.meta.url),
  'utf8',
)

test('new iOS builds generate and adjust training plans without Edge LLM endpoints', () => {
  assert.doesNotMatch(trainingPlanService, /functions\/v1\/(?:generate|regenerate)-training-plan/)
  assert.match(trainingPlanService, /generateLocalPlan\(/)
  assert.match(trainingPlanService, /adjustPlanLocally\(/)
})

test('the app requires iOS 27 and gates the experience on Apple Intelligence', () => {
  assert.doesNotMatch(project, /IPHONEOS_DEPLOYMENT_TARGET = 18\.2/)
  assert.match(project, /IPHONEOS_DEPLOYMENT_TARGET = 27\.0/)
  assert.match(contentView, /deviceNotEligible/)
  assert.match(contentView, /appleIntelligenceNotEnabled/)
  assert.match(contentView, /modelNotReady/)
  assert.match(foundationModelsService, /OnDeviceModelAvailability/)
})

test('training plans are loaded locally and personalized with the Apple model', () => {
  assert.doesNotMatch(trainingPlanService, /functions\/v1\/training-plan/)
  assert.doesNotMatch(trainingPlanService, /URLSession\.shared/)
  assert.match(trainingPlanService, /personalizePlanLocally/)
  assert.match(trainingPlanService, /FoundationModelsService\.shared/)
})
