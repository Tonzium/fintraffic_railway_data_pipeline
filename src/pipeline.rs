/// Pipeline stage definitions and status tracking

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PipelineStage {
    Ingestion,
    Transformation,
    Dashboard,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum StageStatus {
    Pending,
    Running,
    Completed,
    Failed,
}

pub struct PipelineStatus {
    pub ingestion: StageStatus,
    pub transformation: StageStatus,
    pub dashboard: StageStatus,
}

impl PipelineStatus {
    pub fn new() -> Self {
        Self {
            ingestion: StageStatus::Pending,
            transformation: StageStatus::Pending,
            dashboard: StageStatus::Pending,
        }
    }

    pub fn reset(&mut self) {
        self.ingestion = StageStatus::Pending;
        self.transformation = StageStatus::Pending;
        self.dashboard = StageStatus::Pending;
    }

    pub fn set_stage_running(&mut self, stage: PipelineStage) {
        match stage {
            PipelineStage::Ingestion => self.ingestion = StageStatus::Running,
            PipelineStage::Transformation => self.transformation = StageStatus::Running,
            PipelineStage::Dashboard => self.dashboard = StageStatus::Running,
        }
    }

    pub fn set_stage_completed(&mut self, stage: PipelineStage) {
        match stage {
            PipelineStage::Ingestion => self.ingestion = StageStatus::Completed,
            PipelineStage::Transformation => self.transformation = StageStatus::Completed,
            PipelineStage::Dashboard => self.dashboard = StageStatus::Completed,
        }
    }

    pub fn set_stage_failed(&mut self, stage: PipelineStage) {
        match stage {
            PipelineStage::Ingestion => self.ingestion = StageStatus::Failed,
            PipelineStage::Transformation => self.transformation = StageStatus::Failed,
            PipelineStage::Dashboard => self.dashboard = StageStatus::Failed,
        }
    }

    pub fn is_stage_completed(&self, stage: PipelineStage) -> bool {
        match stage {
            PipelineStage::Ingestion => self.ingestion == StageStatus::Completed,
            PipelineStage::Transformation => self.transformation == StageStatus::Completed,
            PipelineStage::Dashboard => self.dashboard == StageStatus::Completed,
        }
    }

    pub fn all_completed(&self) -> bool {
        self.ingestion == StageStatus::Completed
            && self.transformation == StageStatus::Completed
            && self.dashboard == StageStatus::Completed
    }

    pub fn has_failures(&self) -> bool {
        self.ingestion == StageStatus::Failed
            || self.transformation == StageStatus::Failed
            || self.dashboard == StageStatus::Failed
    }
}
