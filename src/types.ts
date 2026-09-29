// SPDX-License-Identifier: MIT

export type PolicyType = "riskx" | "compliance" | "agent";

export interface RiskXPersona {
  type: "riskx";
  id: "alice" | "bob";
  name: string;
  category: string;
  claim: {
    liquid_net_worth_usd: number;
    consecutive_monthly_inflows: number;
    annual_inflow_usd: number;
    total_liabilities_usd: number;
    successful_repayments: number;
    total_historical_loans: number;
    liquidation_count: number;
  };
  secretByte: number;
  tier: number;
  tierLabel: string;
  ltvBps: number;
  collateralRatio: number;
  score: number;
}

export interface CompliancePersona {
  type: "compliance";
  id: "carol" | "erin" | "dave";
  name: string;
  category: string;
  claim: {
    jurisdiction_code: string;
    liquid_net_worth_usd: number;
    annual_income_usd: number;
    is_politically_exposed: boolean;
    identity_hash: string;
  };
  secretByte: number;
  statusCode: number;
  statusLabel: string;
  isAccredited: boolean;
  isSanctioned: boolean;
  spotAllowed: boolean;
  rwaAllowed: boolean;
}

export interface AgentPersona {
  type: "agent";
  id: "alpha" | "beta" | "gamma";
  name: string;
  category: string;
  claim: {
    developer_address: string;
    agent_code_hash: string;
    max_daily_allowance_usd: number;
    max_drawdown_bps: number;
    permitted_contracts: string[];
  };
  secretByte: number;
  statusCode: number;
  statusLabel: string;
  flags: number;
  dailyAllowanceUsd: number;
  maxDrawdownPct: number;
  isAttested: boolean;
  isRestricted: boolean;
  isRogue: boolean;
  testPaymentUsd: number;
  testPaymentRequestId: `0x${string}`;
}

export type Persona = RiskXPersona | CompliancePersona | AgentPersona;

export interface NetworkConfig {
  name: string;
  registry: `0x${string}`;
  trigger: `0x${string}`;
  settler: string;
  hasTrigger: boolean;
  gasLabel: string;
}
