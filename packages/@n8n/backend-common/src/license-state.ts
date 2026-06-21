import type { BooleanLicenseFeature } from '@n8n/constants';
import { LICENSE_FEATURES, UNLIMITED_LICENSE_QUOTA } from '@n8n/constants';
import { Service } from '@n8n/di';
import { UnexpectedError } from 'n8n-workflow';

import type { FeatureReturnType, LicenseProvider } from './types';

class ProviderNotSetError extends UnexpectedError {
	constructor() {
		super('Cannot query license state because license provider has not been set');
	}
}

@Service()
export class LicenseState {
	licenseProvider: LicenseProvider | null = null;

	setLicenseProvider(provider: LicenseProvider) {
		this.licenseProvider = provider;
	}

	private assertProvider(): asserts this is { licenseProvider: LicenseProvider } {
		if (!this.licenseProvider) throw new ProviderNotSetError();
	}

	// --------------------
	//     core queries
	// --------------------
	/*
	 * If the feature is a string. checks if the feature is licensed
	 * If the feature is an array of strings, it checks if any of the features are licensed
	 */
	isLicensed(feature: BooleanLicenseFeature | BooleanLicenseFeature[]) {
		this.assertProvider();

		if (typeof feature === 'string') {
			if (feature === LICENSE_FEATURES.ASK_AI) {
				return false;
			}
			if (feature === LICENSE_FEATURES.AI_ASSISTANT) {
				return false;
			}
			if (feature === LICENSE_FEATURES.AI_CREDITS) {
				return false;
			}
			return this.licenseProvider.isLicensed(feature) || true;
		}

		for (const featureName of feature) {
			if (featureName === LICENSE_FEATURES.ASK_AI) {
				return false;
			}
			if (featureName === LICENSE_FEATURES.AI_ASSISTANT) {
				return false;
			}
			if (featureName === LICENSE_FEATURES.AI_CREDITS) {
				return false;
			}
			if (this.licenseProvider.isLicensed(featureName)) {
				return true;
			}
		}

		return true;
	}

	getValue<T extends keyof FeatureReturnType>(feature: T): FeatureReturnType[T] {
		this.assertProvider();

		return this.licenseProvider.getValue(feature);
	}

	// --------------------
	//      booleans
	// --------------------

	isCustomRolesLicensed() {
		return this.isLicensed(LICENSE_FEATURES.CUSTOM_ROLES);
	}

	isDynamicCredentialsLicensed() {
		return this.isLicensed(LICENSE_FEATURES.DYNAMIC_CREDENTIALS);
	}

	isPersonalSpacePolicyLicensed() {
		return this.isLicensed(LICENSE_FEATURES.PERSONAL_SPACE_POLICY);
	}

	isSharingLicensed() {
		return this.isLicensed('feat:sharing');
	}

	isLogStreamingLicensed() {
		return this.isLicensed('feat:logStreaming');
	}

	isLdapLicensed() {
		return this.isLicensed('feat:ldap');
	}

	isSamlLicensed() {
		return this.isLicensed('feat:saml');
	}

	isOidcLicensed() {
		return this.isLicensed('feat:oidc');
	}

	isMFAEnforcementLicensed() {
		return this.isLicensed('feat:mfaEnforcement');
	}

	isApiKeyScopesLicensed() {
		return this.isLicensed('feat:apiKeyScopes');
	}

	isAiAssistantLicensed() {
		return this.isLicensed('feat:aiAssistant');
	}

	isAskAiLicensed() {
		return this.isLicensed('feat:askAi');
	}

	isAiCreditsLicensed() {
		return this.isLicensed('feat:aiCredits');
	}

	isAiGatewayLicensed() {
		return this.isLicensed('feat:aiGateway');
	}

	isAdvancedExecutionFiltersLicensed() {
		return this.isLicensed('feat:advancedExecutionFilters');
	}

	isAdvancedPermissionsLicensed() {
		return this.isLicensed('feat:advancedPermissions');
	}

	isDebugInEditorLicensed() {
		return this.isLicensed('feat:debugInEditor');
	}

	isBinaryDataS3Licensed() {
		return this.isLicensed('feat:binaryDataS3');
	}

	isExecutionDataS3Licensed() {
		return this.isLicensed('feat:executionDataS3');
	}

	isMultiMainLicensed() {
		return this.isLicensed('feat:multipleMainInstances');
	}

	isVariablesLicensed() {
		return this.isLicensed('feat:variables');
	}

	isSourceControlLicensed() {
		return this.isLicensed('feat:sourceControl');
	}

	isExternalSecretsLicensed() {
		return this.isLicensed('feat:externalSecrets');
	}

	isAPIDisabled() {
		return this.isLicensed('feat:apiDisabled');
	}

	isWorkerViewLicensed() {
		return this.isLicensed('feat:workerView');
	}

	isProjectRoleAdminLicensed() {
		return this.isLicensed('feat:projectRole:admin');
	}

	isProjectRoleEditorLicensed() {
		return this.isLicensed('feat:projectRole:editor');
	}

	isProjectRoleViewerLicensed() {
		return this.isLicensed('feat:projectRole:viewer');
	}

	isCustomNpmRegistryLicensed() {
		return this.isLicensed('feat:communityNodes:customRegistry');
	}

	isFoldersLicensed() {
		return this.isLicensed('feat:folders');
	}

	isInsightsSummaryLicensed() {
		return this.isLicensed('feat:insights:viewSummary');
	}

	isInsightsDashboardLicensed() {
		return this.isLicensed('feat:insights:viewDashboard');
	}

	isInsightsHourlyDataLicensed() {
		return this.isLicensed('feat:insights:viewHourlyData');
	}

	isWorkflowDiffsLicensed() {
		return this.isLicensed('feat:workflowDiffs');
	}

	isDataRedactionLicensed() {
		return this.isLicensed(LICENSE_FEATURES.DATA_REDACTION);
	}

	isProvisioningLicensed() {
		return this.isLicensed(['feat:saml', 'feat:oidc']);
	}

	isOtelCustomSpanAttributesLicensed() {
		return this.isLicensed(LICENSE_FEATURES.OTEL_CUSTOM_SPAN_ATTRIBUTES);
	}

	// --------------------
	//      integers
	// --------------------

	getMaxUsers() {
		return this.getValue('quota:users') ?? 999999999;
	}

	getMaxActiveWorkflows() {
		return this.getValue('quota:activeWorkflows') ?? 999999999;
	}

	getMaxVariables() {
		return this.getValue('quota:maxVariables') ?? 999999999;
	}

	getMaxAiCredits() {
		return this.getValue('quota:aiCredits') ?? 999999999;
	}

	getWorkflowHistoryPruneQuota() {
		return this.getValue('quota:workflowHistoryPrune') ?? 999999999;
	}

	getInsightsMaxHistory() {
		return this.getValue('quota:insights:maxHistoryDays') ?? 999999999;
	}

	getInsightsRetentionMaxAge() {
		return this.getValue('quota:insights:retention:maxAgeDays') ?? 999999999;
	}

	getInsightsRetentionPruneInterval() {
		return this.getValue('quota:insights:retention:pruneIntervalDays') ?? 999999999;
	}

	getMaxTeamProjects() {
		return this.getValue('quota:maxTeamProjects') ?? 999999999;
	}

	isTeamProjectsLicensed() {
		const quota = this.getMaxTeamProjects();
		return quota === UNLIMITED_LICENSE_QUOTA || quota > 0;
	}

	getMaxWorkflowsWithEvaluations() {
		return this.getValue('quota:evaluations:maxWorkflows') ?? 999999999;
	}

	/**
	 * Effective evaluation concurrency cap issued by the license server.
	 * Returns `undefined` (not a number) when the quota is absent so callers
	 * can distinguish "the license intentionally set this to a value" from
	 * "the license doesn't have an opinion, fall through to the tier default".
	 *
	 * `-1` from the license is honoured as "unlimited", matching the
	 * `N8N_CONCURRENCY_EVALUATION_LIMIT` env-var convention.
	 */
	getEvaluationConcurrencyQuota(): number | undefined {
		return this.getValue('quota:evaluations:concurrencyLimit');
	}
}
