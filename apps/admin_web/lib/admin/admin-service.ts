import {
  getOverviewMetricsAction,
  getShipmentsListAction,
  getBatchesListAction,
  getPersonnelListAction,
  getOperatingHubsAction,
  getIncidentsListAction,
  getAuditLogsAction,
  getConfigurationAction,
  correctReceiverDetailsAction,
  setPersonnelStatusAction,
  resolveIncidentAction,
  toggleCorridorActiveAction,
  updatePricingRuleAction,
} from './admin-actions'
import type {
  AdminOverviewMetrics,
  AdminShipmentSummary,
  AdminPersonnelSummary,
  AdminIncidentSummary,
  AdminAuditLog,
  AdminConfiguration,
  AdminBatchSummary,
  OperatingHub,
} from '@/types/admin'

export class AdminService {
  async getOverviewMetrics(): Promise<AdminOverviewMetrics | null> {
    const res = await getOverviewMetricsAction()
    if (res.error) {
      console.error('getOverviewMetricsAction error:', res.error)
      return null
    }
    return res.data
  }

  async getShipmentsList(params?: {
    search?: string
    status?: string
  }): Promise<{ data: AdminShipmentSummary[]; error: string | null }> {
    const res = await getShipmentsListAction(params)
    if (res.error) {
      console.error('getShipmentsListAction error:', res.error)
    }
    return res
  }

  async correctReceiverDetails(
    shipmentId: string,
    payload: { newPhone?: string; newAddress?: string; reason: string }
  ): Promise<boolean> {
    return correctReceiverDetailsAction(shipmentId, payload)
  }

  async getPersonnelList(): Promise<{ data: AdminPersonnelSummary[]; error: string | null }> {
    const res = await getPersonnelListAction()
    if (res.error) {
      console.error('getPersonnelListAction error:', res.error)
    }
    return res
  }

  async setPersonnelStatus(
    personnelId: string,
    isActive: boolean,
    reason: string
  ): Promise<boolean> {
    return setPersonnelStatusAction(personnelId, isActive, reason)
  }

  async getOperatingHubs(): Promise<OperatingHub[]> {
    return getOperatingHubsAction()
  }

  async getBatchesList(): Promise<{ data: AdminBatchSummary[]; error: string | null }> {
    const res = await getBatchesListAction()
    if (res.error) {
      console.error('getBatchesListAction error:', res.error)
    }
    return res
  }

  async getIncidentsList(status?: string): Promise<AdminIncidentSummary[]> {
    return getIncidentsListAction(status)
  }

  async resolveIncident(incidentId: string, resolutionNotes: string): Promise<boolean> {
    return resolveIncidentAction(incidentId, resolutionNotes)
  }

  async getConfiguration(): Promise<AdminConfiguration | null> {
    return getConfigurationAction()
  }

  async toggleCorridorActive(
    corridorId: string,
    isActive: boolean,
    reason: string
  ): Promise<boolean> {
    return toggleCorridorActiveAction(corridorId, isActive, reason)
  }

  async updatePricingRule(
    pricingRuleId: string,
    basePriceKobo: number,
    reason: string
  ): Promise<boolean> {
    return updatePricingRuleAction(pricingRuleId, basePriceKobo, reason)
  }

  async getAuditLogs(limit = 50): Promise<AdminAuditLog[]> {
    return getAuditLogsAction(limit)
  }
}

export const adminService = new AdminService()
